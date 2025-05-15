// SPDX-License-Identifier: Apache-2.0

use starknet::{ContractAddress, get_block_timestamp, get_tx_info};
use core::array::ArrayTrait;
use core::num::traits::Zero;
use core::traits::PartialOrd;
use starknet::storage::{StoragePointerReadAccess, StoragePointerWriteAccess, StoragePathEntry, Map};

#[derive(Drop, Serde, starknet::Store)]
pub struct AllocationDetails {
    workflow_id: u256,
    sign_id: u256,
    recipient: ContractAddress,
    amount: u256,
    token_address: ContractAddress,
    tx_hash: felt252,
    created_at: u64,
    status: felt252, // 0: pending, 1: executed, 2: failed
}

/// Allocation Contract Interface
#[starknet::interface]
pub trait IAllocation<TContractState> {
    /// Create allocation record
    fn create_allocation(
        ref self: TContractState,
        workflow_id: u256,
        sign_id: u256,
        recipient: ContractAddress,
        amount: u256,
        token_address: ContractAddress
    ) -> u256;

    /// Update allocation status
    fn update_allocation_status(ref self: TContractState, allocation_id: u256, status: felt252) -> bool;

    /// Get allocation details
    fn get_allocation_details(self: @TContractState, allocation_id: u256) -> AllocationDetails;

    /// Get allocation ID by sign ID
    fn get_allocation_by_sign(self: @TContractState, sign_id: u256) -> u256;
}

/// Allocation Contract Implementation
#[starknet::contract]
mod AllocationContract {
    use super::{ContractAddress, get_tx_info, ArrayTrait};
    use super::{AllocationDetails};
    use core::num::traits::Zero;
    use core::traits::PartialOrd;
    use starknet::storage::{StoragePointerReadAccess, StoragePointerWriteAccess, StoragePathEntry, Map};
    use starknet::get_block_timestamp;

    #[storage]
    struct Storage {
        allocations: Map<u256, AllocationDetails>,
        allocation_count: u256,
        sign_to_allocation: Map<u256, u256>, // sign_id -> allocation_id
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        AllocationCreated: AllocationCreated,
        AllocationProcessed: AllocationProcessed,
    }

    #[derive(Drop, starknet::Event)]
    struct AllocationCreated {
        allocation_id: u256,
        workflow_id: u256,
        sign_id: u256,
        recipient: ContractAddress,
        amount: u256,
        token_address: ContractAddress,
        tx_hash: felt252,
    }

    #[derive(Drop, starknet::Event)]
    struct AllocationProcessed {
        allocation_id: u256,
        tx_hash: felt252,
    }

    #[abi(embed_v0)]
    impl AllocationImpl of super::IAllocation<ContractState> {
        fn create_allocation(
            ref self: ContractState,
            workflow_id: u256,
            sign_id: u256,
            recipient: ContractAddress,
            amount: u256,
            token_address: ContractAddress
        ) -> u256 {
            // Validate input parameters
            assert(sign_id != 0_u256, 'Sign ID cannot be zero');
            assert(amount != 0_u256, 'Amount cannot be zero');
            assert(!recipient.is_zero(), 'Invalid recipient address');
            assert(!token_address.is_zero(), 'Invalid token address');
            
            // Check if an allocation has already been created for this sign
            let existing_allocation_id = self.sign_to_allocation.entry(sign_id).read();
            assert(existing_allocation_id == 0_u256, 'Sign already has allocation');
            
            // Get current transaction information
            let tx_info = get_tx_info().unbox();
            let tx_hash = tx_info.transaction_hash;
            
            // Generate new allocation ID
            let allocation_id = self.allocation_count.read() + 1_u256;
            self.allocation_count.write(allocation_id);
            
            // Store allocation information
            self.allocations.entry(allocation_id).write(
                AllocationDetails {
                    workflow_id,
                    sign_id,
                    recipient,
                    amount,
                    token_address,
                    tx_hash,
                    created_at: get_block_timestamp(),
                    status: 0_felt252,
                }
            );
            
            // Record mapping from sign_id to allocation_id
            self.sign_to_allocation.entry(sign_id).write(allocation_id);
            
            // Trigger event
            self.emit(AllocationCreated {
                allocation_id,
                workflow_id,
                sign_id,
                recipient,
                amount,
                token_address,
                tx_hash,
            });
            
            allocation_id
        }
        
        fn update_allocation_status(ref self: ContractState, allocation_id: u256, status: felt252) -> bool {
            // Validate parameters
            assert(allocation_id != 0_u256, 'Invalid allocation ID');
            assert(status == 0_felt252 || status == 1_felt252 || status == 2_felt252, 'Invalid status value');
            
            // Verify allocation exists
            let allocation = self.allocations.entry(allocation_id).read();
            assert(allocation.created_at != 0_u64, 'Allocation does not exist');
            
            // Permission check should be added here to ensure only authorized parties can call
            
            // Get current transaction information
            let tx_info = get_tx_info().unbox();
            let tx_hash = tx_info.transaction_hash;
            
            // Update allocation status
            let _updated_allocation = AllocationDetails {
                workflow_id: allocation.workflow_id,
                sign_id: allocation.sign_id,
                recipient: allocation.recipient,
                amount: allocation.amount,
                token_address: allocation.token_address,
                tx_hash: allocation.tx_hash,
                created_at: allocation.created_at,
                status,
            };
            self.allocations.entry(allocation_id).write(_updated_allocation);
            
            // Trigger event
            self.emit(AllocationProcessed {
                allocation_id,
                tx_hash,
            });
            
            true
        }
        
        fn get_allocation_details(self: @ContractState, allocation_id: u256) -> AllocationDetails {
            self.allocations.entry(allocation_id).read()
        }
        
        fn get_allocation_by_sign(self: @ContractState, sign_id: u256) -> u256 {
            self.sign_to_allocation.entry(sign_id).read()
        }
    }

    // Internal functions
    #[generate_trait]
    impl AllocationInternalImpl of AllocationInternalTrait {
        // Mark allocation as processed (called by multisig wallet callback or administrator)
        fn mark_processed(ref self: ContractState, allocation_id: u256) {
            // Permission check should be added here to ensure only authorized parties can call
            
            // Get current transaction information
            let tx_info = get_tx_info().unbox();
            let tx_hash = tx_info.transaction_hash;
            
            // Update allocation status
            let allocation = self.allocations.entry(allocation_id).read();
            let _updated_allocation = AllocationDetails {
                workflow_id: allocation.workflow_id,
                sign_id: allocation.sign_id,
                recipient: allocation.recipient,
                amount: allocation.amount,
                token_address: allocation.token_address,
                tx_hash: allocation.tx_hash,
                created_at: allocation.created_at,
                status: 1_felt252,
            };
            self.allocations.entry(allocation_id).write(_updated_allocation);
            
            // Trigger event
            self.emit(AllocationProcessed {
                allocation_id,
                tx_hash,
            });
        }
    }
} 
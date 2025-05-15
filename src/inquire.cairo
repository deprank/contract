// SPDX-License-Identifier: Apache-2.0

use starknet::{ContractAddress, get_block_timestamp, get_tx_info};
use core::array::ArrayTrait;
use core::num::traits::Zero;
use starknet::storage::{StoragePointerReadAccess, StoragePointerWriteAccess, StoragePathEntry, Map};

#[derive(Drop, Serde, starknet::Store)]
pub struct InquireDetails {
    workflow_id: u256,
    inquirer: ContractAddress,
    inquiree: ContractAddress,
    question: felt252,
    response: felt252,
    status: felt252, // 0: pending, 1: responded, 2: rejected
    created_at: u64,
    responded_at: u64,
}

/// Inquire contract interface
#[starknet::interface]
pub trait IInquire<TContractState> {
    /// Create inquiry
    fn create_inquire(
        ref self: TContractState,
        workflow_id: u256,
        inquirer: ContractAddress,
        inquiree: ContractAddress,
        question: felt252
    ) -> u256;

    /// Respond to inquiry
    fn respond_to_inquire(ref self: TContractState, inquire_id: u256, response: felt252) -> bool;

    /// Reject inquiry
    fn reject_inquire(ref self: TContractState, inquire_id: u256) -> bool;

    /// Get inquiry details
    fn get_inquire_details(self: @TContractState, inquire_id: u256) -> InquireDetails;
}

/// Inquire contract implementation
#[starknet::contract]
mod InquireContract {
    use super::{ContractAddress, get_block_timestamp, get_tx_info, ArrayTrait};
    use super::{InquireDetails};
    use core::num::traits::Zero;
    use starknet::storage::{StoragePointerReadAccess, StoragePointerWriteAccess, StoragePathEntry, Map};

    #[storage]
    struct Storage {
        inquires: Map<u256, InquireDetails>,
        inquire_count: u256,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        InquireCreated: InquireCreated,
        InquireStateChanged: InquireStateChanged,
    }

    #[derive(Drop, starknet::Event)]
    struct InquireCreated {
        inquire_id: u256,
        workflow_id: u256,
        inquirer: ContractAddress,
        inquiree: ContractAddress,
        question: felt252,
        tx_hash: felt252,
    }

    #[derive(Drop, starknet::Event)]
    struct InquireStateChanged {
        inquire_id: u256,
        previous_state: felt252,
        new_state: felt252,
        tx_hash: felt252,
    }

    #[abi(embed_v0)]
    impl InquireImpl of super::IInquire<ContractState> {
        fn create_inquire(
            ref self: ContractState,
            workflow_id: u256,
            inquirer: ContractAddress,
            inquiree: ContractAddress,
            question: felt252
        ) -> u256 {
            // Validate input parameters
            assert(workflow_id != 0_u256, 'Workflow ID cannot be zero');
            assert(!inquirer.is_zero(), 'Invalid inquirer address');
            assert(!inquiree.is_zero(), 'Invalid inquiree address');
            assert(question != 0, 'Question cannot be empty');
            assert(inquirer != inquiree, 'Inquirer cannot be inquiree');

            // Get current transaction information
            let tx_info = get_tx_info().unbox();
            let tx_hash = tx_info.transaction_hash;
            
            // Generate new inquiry form ID
            let inquire_id = self.inquire_count.read() + 1_u256;
            self.inquire_count.write(inquire_id);
            
            let _current_time = get_block_timestamp();
            
            // Store inquiry form information
            self.inquires.entry(inquire_id).write(
                InquireDetails {
                    workflow_id,
                    inquirer,
                    inquiree,
                    question,
                    response: 0, // Initial response: 0 (pending)
                    status: 0, // Initial status: 0 (pending)
                    created_at: _current_time,
                    responded_at: 0, // Initial response time: 0 (not responded)
                }
            );
            
            // Trigger event
            self.emit(InquireCreated {
                inquire_id,
                workflow_id,
                inquirer,
                inquiree,
                question,
                tx_hash,
            });
            
            inquire_id
        }
        
        fn respond_to_inquire(ref self: ContractState, inquire_id: u256, response: felt252) -> bool {
            // Validate parameters
            assert(inquire_id != 0_u256, 'Invalid inquire ID');
            assert(response != 0, 'Response cannot be empty');
            
            // Get current transaction information
            let tx_info = get_tx_info().unbox();
            let tx_hash = tx_info.transaction_hash;
            let caller = tx_info.account_contract_address;
            
            // Read current inquiry form
            let inquire = self.inquires.entry(inquire_id).read();
            assert(inquire.created_at != 0_u64, 'Inquire does not exist');
            assert(inquire.status == 0, 'Inquire not in pending status');
            
            // Verify that responder is the inquiree
            assert(caller == inquire.inquiree, 'Only inquiree can respond');
            
            // Save old status for event
            let previous_status = inquire.status;
            
            // Create updated inquiry form
            let _updated_inquire = InquireDetails {
                workflow_id: inquire.workflow_id,
                inquirer: inquire.inquirer,
                inquiree: inquire.inquiree,
                question: inquire.question,
                response: response,
                status: 1, // Update status to responded
                created_at: inquire.created_at,
                responded_at: get_block_timestamp(),
            };
            
            // Write back to storage
            self.inquires.entry(inquire_id).write(_updated_inquire);
            
            // Trigger status change event
            self.emit(InquireStateChanged {
                inquire_id,
                previous_state: previous_status,
                new_state: 1, // Responded status
                tx_hash,
            });
            
            true
        }
        
        fn reject_inquire(ref self: ContractState, inquire_id: u256) -> bool {
            // Validate parameters
            assert(inquire_id != 0_u256, 'Invalid inquire ID');
            
            // Get current transaction information
            let tx_info = get_tx_info().unbox();
            let tx_hash = tx_info.transaction_hash;
            let caller = tx_info.account_contract_address;
            
            // Read current inquiry form
            let inquire = self.inquires.entry(inquire_id).read();
            assert(inquire.created_at != 0_u64, 'Inquire does not exist');
            assert(inquire.status == 0, 'Inquire not in pending status');
            
            // Verify that rejector is the inquiree
            assert(caller == inquire.inquiree, 'Only inquiree can reject');
            
            // Save old status for event
            let previous_status = inquire.status;
            
            // Create updated inquiry form
            let _updated_inquire = InquireDetails {
                workflow_id: inquire.workflow_id,
                inquirer: inquire.inquirer,
                inquiree: inquire.inquiree,
                question: inquire.question,
                response: 0, // No response for rejected inquiries
                status: 2, // Update status to rejected
                created_at: inquire.created_at,
                responded_at: get_block_timestamp(), // Record rejection time
            };
            
            // Write back to storage
            self.inquires.entry(inquire_id).write(_updated_inquire);
            
            // Trigger status change event
            self.emit(InquireStateChanged {
                inquire_id,
                previous_state: previous_status,
                new_state: 2, // Rejected status
                tx_hash,
            });
            
            true
        }
        
        fn get_inquire_details(self: @ContractState, inquire_id: u256) -> InquireDetails {
            self.inquires.entry(inquire_id).read()
        }
    }
} 
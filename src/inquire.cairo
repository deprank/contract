// SPDX-License-Identifier: Apache-2.0

use starknet::{ContractAddress, get_block_timestamp, get_tx_info};
use core::array::ArrayTrait;
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
        receipt_id: u256,
        receipt_tx_hash: felt252,
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
                receipt_id: 0, // This needs to be filled according to actual situation
                receipt_tx_hash: 0, // This needs to be filled according to actual situation
                tx_hash,
            });
            
            inquire_id
        }
        
        fn respond_to_inquire(ref self: ContractState, inquire_id: u256, response: felt252) -> bool {
            // Get current transaction information
            let tx_info = get_tx_info().unbox();
            let tx_hash = tx_info.transaction_hash;
            
            // Read current inquiry form
            let inquire = self.inquires.entry(inquire_id).read();
            
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
                new_state: 1, // This needs to be filled according to actual situation
                tx_hash,
            });
            
            true
        }
        
        fn reject_inquire(ref self: ContractState, inquire_id: u256) -> bool {
            // Get current transaction information
            let tx_info = get_tx_info().unbox();
            let tx_hash = tx_info.transaction_hash;
            
            // Read current inquiry form
            let inquire = self.inquires.entry(inquire_id).read();
            
            // Save old status for event
            let previous_status = inquire.status;
            
            // Create updated inquiry form
            let _updated_inquire = InquireDetails {
                workflow_id: inquire.workflow_id,
                inquirer: inquire.inquirer,
                inquiree: inquire.inquiree,
                question: inquire.question,
                response: 0, // This needs to be filled according to actual situation
                status: 2, // Update status to rejected
                created_at: inquire.created_at,
                responded_at: 0, // This needs to be filled according to actual situation
            };
            
            // Write back to storage
            self.inquires.entry(inquire_id).write(_updated_inquire);
            
            // Trigger status change event
            self.emit(InquireStateChanged {
                inquire_id,
                previous_state: previous_status,
                new_state: 2, // This needs to be filled according to actual situation
                tx_hash,
            });
            
            true
        }
        
        fn get_inquire_details(self: @ContractState, inquire_id: u256) -> InquireDetails {
            self.inquires.entry(inquire_id).read()
        }
    }
} 
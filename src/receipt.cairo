// SPDX-License-Identifier: Apache-2.0

use starknet::{ContractAddress, get_block_timestamp, get_tx_info};
use core::array::ArrayTrait;
use starknet::storage::{StoragePointerReadAccess, StoragePointerWriteAccess, StoragePathEntry, Map};

#[derive(Drop, Serde, starknet::Store)]
pub struct ReceiptDetails {
    workflow_id: u256,
    dependency_url: felt252,
    tx_hash: felt252,
    created_at: u64,
    metadata_hash: felt252, // Hash value of the complete JSON
    metadata_uri: felt252,  // URI pointing to the complete JSON
}

#[derive(Drop, Serde, starknet::Store)]
pub struct ReceiptMetadata {
    // Common key fields, stored directly on the chain
    pub name: felt252,
    pub version: felt252,
    pub author: felt252,
    pub license: felt252,
    // More fields can be added as needed
}

/// Receipt contract interface
#[starknet::interface]
pub trait IReceipt<TContractState> {
    /// Create receipt and store metadata
    fn create_receipt(
        ref self: TContractState,
        workflow_id: u256,
        dependency_url: felt252,
        metadata: ReceiptMetadata,
        metadata_hash: felt252,
        metadata_uri: felt252
    ) -> u256;

    /// Get receipt details
    fn get_receipt_details(self: @TContractState, receipt_id: u256) -> (ReceiptDetails, ReceiptMetadata);

    /// Verify metadata
    fn verify_metadata(
        self: @TContractState,
        receipt_id: u256,
        provided_hash: felt252
    ) -> bool;

    /// Update transaction hash
    fn update_tx_hash(ref self: TContractState, receipt_id: u256, tx_hash: felt252);
}

/// Receipt contract implementation
#[starknet::contract]
mod ReceiptContract {
    use super::{ContractAddress, get_block_timestamp, get_tx_info, ArrayTrait};
    use super::{ReceiptDetails, ReceiptMetadata};
    use starknet::storage::{StoragePointerReadAccess, StoragePointerWriteAccess, StoragePathEntry, Map};

    #[storage]
    struct Storage {
        receipts: Map<u256, ReceiptDetails>,
        receipt_count: u256,
        // Key metadata fields
        receipt_metadata: Map<u256, ReceiptMetadata>,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        ReceiptCreated: ReceiptCreated,
    }

    #[derive(Drop, starknet::Event)]
    struct ReceiptCreated {
        receipt_id: u256,
        workflow_id: u256,
        dependency_url: felt252,
        tx_hash: felt252,
        metadata_uri: felt252,
    }

    #[abi(embed_v0)]
    impl ReceiptImpl of super::IReceipt<ContractState> {
        fn create_receipt(
            ref self: ContractState,
            workflow_id: u256,
            dependency_url: felt252,
            metadata: ReceiptMetadata,
            metadata_hash: felt252,
            metadata_uri: felt252
        ) -> u256 {
            // Validate input parameters
            assert(workflow_id != 0_u256, 'Workflow ID cannot be zero');
            assert(dependency_url != 0, 'Dependency URL cannot be empty');
            assert(metadata_hash != 0, 'Metadata hash cannot be empty');
            assert(metadata_uri != 0, 'Metadata URI cannot be empty');
            assert(metadata.name != 0, 'Metadata name cannot be empty');
            
            // Get current transaction information
            let tx_info = get_tx_info().unbox();
            let tx_hash = tx_info.transaction_hash;
            
            // Generate new receipt ID
            let receipt_id = self.receipt_count.read() + 1_u256;
            self.receipt_count.write(receipt_id);
            
            // Store basic information
            self.receipts.entry(receipt_id).write(
                ReceiptDetails {
                    workflow_id,
                    dependency_url,
                    tx_hash,
                    created_at: get_block_timestamp(),
                    metadata_hash,
                    metadata_uri,
                }
            );
            
            // Store key metadata
            self.receipt_metadata.entry(receipt_id).write(metadata);
            
            // Trigger event
            self.emit(ReceiptCreated {
                receipt_id,
                workflow_id,
                dependency_url,
                tx_hash,
                metadata_uri,
            });
            
            receipt_id
        }
        
        fn get_receipt_details(self: @ContractState, receipt_id: u256) -> (ReceiptDetails, ReceiptMetadata) {
            // Validate parameters
            assert(receipt_id != 0_u256, 'Receipt ID cannot be zero');
            
            // Get receipt details
            let receipt = self.receipts.entry(receipt_id).read();
            
            // Verify receipt exists
            assert(receipt.created_at != 0_u64, 'Receipt not found');
            
            (
                receipt,
                self.receipt_metadata.entry(receipt_id).read()
            )
        }
        
        fn verify_metadata(
            self: @ContractState,
            receipt_id: u256,
            provided_hash: felt252
        ) -> bool {
            // Validate parameters
            assert(receipt_id != 0_u256, 'Receipt ID cannot be zero');
            assert(provided_hash != 0, 'Provided hash cannot be empty');
            
            // Get receipt details
            let receipt = self.receipts.entry(receipt_id).read();
            
            // Verify receipt exists
            assert(receipt.created_at != 0_u64, 'Receipt not found');
            
            // Simple hash comparison
            provided_hash == receipt.metadata_hash
        }
        
        fn update_tx_hash(ref self: ContractState, receipt_id: u256, tx_hash: felt252) {
            // Validate parameters
            assert(receipt_id != 0_u256, 'Receipt ID cannot be zero');
            assert(tx_hash != 0, 'Tx hash cannot be empty');
            
            // Get receipt details
            let receipt = self.receipts.entry(receipt_id).read();
            
            // Verify receipt exists
            assert(receipt.created_at != 0_u64, 'Receipt not found');
            
            // Only contract owner or authorized parties can update the transaction hash
            // Permission checks can be added here
            
            let updated_receipt = ReceiptDetails {
                workflow_id: receipt.workflow_id,
                dependency_url: receipt.dependency_url,
                tx_hash: tx_hash,
                created_at: receipt.created_at,
                metadata_hash: receipt.metadata_hash,
                metadata_uri: receipt.metadata_uri,
            };
            self.receipts.entry(receipt_id).write(updated_receipt);
        }
    }
} 
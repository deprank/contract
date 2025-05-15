// SPDX-License-Identifier: Apache-2.0

use starknet::{ContractAddress, get_block_timestamp, get_tx_info};
use core::array::ArrayTrait;
use starknet::storage::{StoragePointerReadAccess, StoragePointerWriteAccess, StoragePathEntry, Map};

#[derive(Drop, Serde, starknet::Store)]
pub struct SignDetails {
    workflow_id: u256,
    inquire_id: u256,
    signer: ContractAddress,
    signature_hash: felt252,
    tx_hash: felt252,
    created_at: u64,
}

/// Sign contract interface
#[starknet::interface]
pub trait ISign<TContractState> {
    /// Create signature record
    fn create_sign(
        ref self: TContractState,
        workflow_id: u256,
        inquire_id: u256,
        signer: ContractAddress,
        signature_hash: felt252
    ) -> u256;

    /// Get signature details
    fn get_sign_details(self: @TContractState, sign_id: u256) -> SignDetails;

    /// Get signature ID by inquiry ID
    fn get_sign_by_inquire(self: @TContractState, inquire_id: u256) -> u256;
}

/// Sign contract implementation
#[starknet::contract]
mod SignContract {
    use super::{ContractAddress, get_tx_info, ArrayTrait};
    use super::{SignDetails};
    use starknet::storage::{StoragePointerReadAccess, StoragePointerWriteAccess, StoragePathEntry, Map};
    use starknet::get_block_timestamp;

    #[storage]
    struct Storage {
        signs: Map<u256, SignDetails>,
        sign_count: u256,
        inquire_to_sign: Map<u256, u256>, // inquire_id -> sign_id
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        SignCreated: SignCreated,
    }

    #[derive(Drop, starknet::Event)]
    struct SignCreated {
        sign_id: u256,
        workflow_id: u256,
        inquire_id: u256,
        inquire_tx_hash: felt252,
        signer: ContractAddress,
        tx_hash: felt252,
    }

    #[abi(embed_v0)]
    impl SignImpl of super::ISign<ContractState> {
        fn create_sign(
            ref self: ContractState,
            workflow_id: u256,
            inquire_id: u256,
            signer: ContractAddress,
            signature_hash: felt252
        ) -> u256 {
            // Get current transaction information
            let tx_info = get_tx_info().unbox();
            let tx_hash = tx_info.transaction_hash;
            
            // Check if a signature has already been created for this inquire
            let existing_sign_id = self.inquire_to_sign.entry(inquire_id).read();
            assert(existing_sign_id == 0_u256, 'Inquire already signed');
            
            // Generate new signature ID
            let sign_id = self.sign_count.read() + 1_u256;
            self.sign_count.write(sign_id);
            
            // Store signature information
            self.signs.entry(sign_id).write(
                SignDetails {
                    workflow_id,
                    inquire_id,
                    signer,
                    signature_hash,
                    tx_hash,
                    created_at: get_block_timestamp(),
                }
            );
            
            // Record inquire to sign mapping
            self.inquire_to_sign.entry(inquire_id).write(sign_id);
            
            // Trigger event
            self.emit(SignCreated {
                sign_id,
                workflow_id,
                inquire_id,
                inquire_tx_hash: signature_hash,
                signer,
                tx_hash,
            });
            
            sign_id
        }
        
        fn get_sign_details(self: @ContractState, sign_id: u256) -> SignDetails {
            self.signs.entry(sign_id).read()
        }
        
        fn get_sign_by_inquire(self: @ContractState, inquire_id: u256) -> u256 {
            self.inquire_to_sign.entry(inquire_id).read()
        }
    }
} 
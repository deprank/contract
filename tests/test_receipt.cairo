// SPDX-License-Identifier: Apache-2.0

use core::array::ArrayTrait;
use core::result::ResultTrait;
use starknet::SyscallResultTrait;

use snforge_std::{declare, ContractClassTrait, DeclareResultTrait, DeclareResult, ContractClass};

// Stelle sicher, dass der Pfad zu deinen Vertragsdefinitionen korrekt ist.
// Wenn dein Paketname in Scarb.toml z.B. "my_receipt_project" ist,
// dann wäre es: use my_receipt_project::receipt::{IReceiptDispatcher, IReceiptDispatcherTrait, ReceiptMetadata};
// Basierend auf deinem Pfad "/home/alfred/deprank/contract/Scarb.toml"
// nehme ich an, der Paketname könnte "contract" sein.
use contract::receipt::{IReceiptDispatcher, IReceiptDispatcherTrait, ReceiptMetadata};


#[test]
fn test_contract_deployment() {
    // 1. Declare the contract and get DeclareResult
    let declared_contract_wrapper: DeclareResult =
        ResultTrait::expect(declare("ReceiptContract"), 'Declare failed'); // ASCII-Fehlermeldung

    // 2. Get ContractClass from DeclareResult
    let contract_to_deploy: @ContractClass = declared_contract_wrapper.contract_class();

    // 3. Prepare constructor parameters (your contract has no constructor, so empty)
    let mut constructor_calldata = ArrayTrait::new();

    // 4. Deploy the contract and destructure the result
    let (contract_address, _returned_data): (starknet::ContractAddress, core::array::Span<felt252>) =
        contract_to_deploy.deploy(@constructor_calldata).unwrap_syscall();

    // 5. Create a dispatcher (Dispatcher is not used here, but that's okay for a pure deployment test)
    let _dispatcher = IReceiptDispatcher { contract_address }; // Mark with _ when not directly used

    // 6. Assert that contract was successfully deployed
    let zero_address: starknet::ContractAddress = 0.try_into().unwrap();
    assert(contract_address != zero_address, 'Contract deployment failed'); // ASCII-Fehlermeldung
}

#[test]
fn test_create_receipt() {
    // 1. Declare and deploy the contract
    let declared_contract_wrapper = ResultTrait::expect(declare("ReceiptContract"), 'Declare failed'); // ASCII
    let contract_to_deploy = declared_contract_wrapper.contract_class();
    let mut constructor_calldata = ArrayTrait::new();
    let (contract_address, _): (starknet::ContractAddress, core::array::Span<felt252>) =
        contract_to_deploy.deploy(@constructor_calldata).unwrap_syscall();

    // 2. Create a dispatcher
    let dispatcher = IReceiptDispatcher { contract_address };

    // 3. Create metadata - These variables are correctly defined
    let name = 'test-receipt';
    let version = '1.0.0';
    let author = 'test-author';
    let license = 'MIT';

    // 4. Prepare data
    let workflow_id = 1_u256;
    let dependency_url = 'https://github.com/test/repo';
    let metadata_hash = 0x5678_felt252; // Explicitly marking as felt252 is good practice
    let metadata_uri = 'ipfs://QmTest';

    // 5. Call create_receipt function
    // The struct initialization ReceiptMetadata { name, version, author, license }
    // is correct because local variables have the same names as struct fields
    let receipt_id = dispatcher.create_receipt(
        workflow_id,
        dependency_url,
        ReceiptMetadata { name, version, author, license },
        metadata_hash,
        metadata_uri
    );

    // 6. Verify that receipt_id is 1
    assert(receipt_id == 1_u256, 'Receipt ID should be 1'); // ASCII-Fehlermeldung
}

#[test]
fn test_get_receipt_details() {
    // 1. Deploy the contract
    let declared_contract_wrapper = ResultTrait::expect(declare("ReceiptContract"), 'Declare failed');
    let contract_to_deploy = declared_contract_wrapper.contract_class();
    let mut constructor_calldata = ArrayTrait::new();
    let (contract_address, _): (starknet::ContractAddress, core::array::Span<felt252>) =
        contract_to_deploy.deploy(@constructor_calldata).unwrap_syscall();
    
    let dispatcher = IReceiptDispatcher { contract_address };

    // 2. First create a receipt
    let metadata = ReceiptMetadata {
        name: 'test-receipt',
        version: '1.0.0',
        author: 'test-author',
        license: 'MIT',
    };
    
    let workflow_id = 1_u256;
    let dependency_url = 'https://github.com/test/repo';
    let metadata_hash = 0x5678_felt252;
    let metadata_uri = 'ipfs://QmTest';

    // Create receipt and get ID
    let receipt_id = dispatcher.create_receipt(
        workflow_id,
        dependency_url,
        metadata,
        metadata_hash,
        metadata_uri
    );

    // 3. Get receipt details
    let (_, retrieved_metadata) = dispatcher.get_receipt_details(receipt_id);
    
    // 4. Verify metadata
    assert(retrieved_metadata.name == 'test-receipt', 'Wrong metadata name');
    assert(retrieved_metadata.version == '1.0.0', 'Wrong metadata version');
    assert(retrieved_metadata.author == 'test-author', 'Wrong metadata author');
    assert(retrieved_metadata.license == 'MIT', 'Wrong metadata license');
}

#[test]
#[should_panic(expected: 'Receipt ID cannot be zero')]
fn test_get_receipt_details_with_zero_id() {
    // 1. Deploy the contract
    let declared_contract_wrapper = ResultTrait::expect(declare("ReceiptContract"), 'Declare failed');
    let contract_to_deploy = declared_contract_wrapper.contract_class();
    let mut constructor_calldata = ArrayTrait::new();
    let (contract_address, _): (starknet::ContractAddress, core::array::Span<felt252>) =
        contract_to_deploy.deploy(@constructor_calldata).unwrap_syscall();
    
    let dispatcher = IReceiptDispatcher { contract_address };

    // 2. Try to get receipt with ID 0, should raise an error
    dispatcher.get_receipt_details(0_u256);
}

#[test]
#[should_panic(expected: 'Receipt not found')]
fn test_get_receipt_details_nonexistent() {
    // 1. Deploy the contract
    let declared_contract_wrapper = ResultTrait::expect(declare("ReceiptContract"), 'Declare failed');
    let contract_to_deploy = declared_contract_wrapper.contract_class();
    let mut constructor_calldata = ArrayTrait::new();
    let (contract_address, _): (starknet::ContractAddress, core::array::Span<felt252>) =
        contract_to_deploy.deploy(@constructor_calldata).unwrap_syscall();
    
    let dispatcher = IReceiptDispatcher { contract_address };

    // 2. Try to get non-existent receipt ID, should raise an error
    dispatcher.get_receipt_details(999_u256);
}

#[test]
fn test_verify_metadata() {
    // 1. Deploy the contract
    let declared_contract_wrapper = ResultTrait::expect(declare("ReceiptContract"), 'Declare failed');
    let contract_to_deploy = declared_contract_wrapper.contract_class();
    let mut constructor_calldata = ArrayTrait::new();
    let (contract_address, _): (starknet::ContractAddress, core::array::Span<felt252>) =
        contract_to_deploy.deploy(@constructor_calldata).unwrap_syscall();
    
    let dispatcher = IReceiptDispatcher { contract_address };

    // 2. Create a receipt
    let metadata = ReceiptMetadata {
        name: 'test-receipt',
        version: '1.0.0',
        author: 'test-author',
        license: 'MIT',
    };
    
    let workflow_id = 1_u256;
    let dependency_url = 'https://github.com/test/repo';
    let metadata_hash = 0x5678_felt252;
    let metadata_uri = 'ipfs://QmTest';

    // Create receipt and get ID
    let receipt_id = dispatcher.create_receipt(
        workflow_id,
        dependency_url,
        metadata,
        metadata_hash,
        metadata_uri
    );

    // 3. Verify with the same hash - should return true
    let is_valid = dispatcher.verify_metadata(receipt_id, metadata_hash);
    assert(is_valid == true, 'Metadata should be valid');

    // 4. Verify with a different hash - should return false
    let wrong_hash = 0x9876_felt252;
    let is_invalid = dispatcher.verify_metadata(receipt_id, wrong_hash);
    assert(is_invalid == false, 'Should detect invalid hash');
}

#[test]
#[should_panic(expected: 'Receipt ID cannot be zero')]
fn test_verify_metadata_with_zero_id() {
    // 1. Deploy the contract
    let declared_contract_wrapper = ResultTrait::expect(declare("ReceiptContract"), 'Declare failed');
    let contract_to_deploy = declared_contract_wrapper.contract_class();
    let mut constructor_calldata = ArrayTrait::new();
    let (contract_address, _): (starknet::ContractAddress, core::array::Span<felt252>) =
        contract_to_deploy.deploy(@constructor_calldata).unwrap_syscall();
    
    let dispatcher = IReceiptDispatcher { contract_address };

    // 2. Try to verify receipt with ID 0, should raise an error
    dispatcher.verify_metadata(0_u256, 0x1234_felt252);
}

#[test]
#[should_panic(expected: 'Provided hash cannot be empty')]
fn test_verify_metadata_with_empty_hash() {
    // 1. Deploy the contract
    let declared_contract_wrapper = ResultTrait::expect(declare("ReceiptContract"), 'Declare failed');
    let contract_to_deploy = declared_contract_wrapper.contract_class();
    let mut constructor_calldata = ArrayTrait::new();
    let (contract_address, _): (starknet::ContractAddress, core::array::Span<felt252>) =
        contract_to_deploy.deploy(@constructor_calldata).unwrap_syscall();
    
    let dispatcher = IReceiptDispatcher { contract_address };

    // 2. First create a receipt
    let receipt_id = dispatcher.create_receipt(
        1_u256,
        'https://github.com/test/repo',
        ReceiptMetadata { name: 'test', version: '1.0', author: 'author', license: 'MIT' },
        0x1234_felt252,
        'ipfs://test'
    );

    // 3. Try to verify with empty hash, should raise an error
    dispatcher.verify_metadata(receipt_id, 0);
}

#[test]
fn test_update_tx_hash() {
    // 1. Deploy the contract
    let declared_contract_wrapper = ResultTrait::expect(declare("ReceiptContract"), 'Declare failed');
    let contract_to_deploy = declared_contract_wrapper.contract_class();
    let mut constructor_calldata = ArrayTrait::new();
    let (contract_address, _): (starknet::ContractAddress, core::array::Span<felt252>) =
        contract_to_deploy.deploy(@constructor_calldata).unwrap_syscall();
    
    let dispatcher = IReceiptDispatcher { contract_address };

    // 2. Create a receipt
    let metadata = ReceiptMetadata {
        name: 'test-receipt',
        version: '1.0.0',
        author: 'test-author',
        license: 'MIT',
    };
    
    let workflow_id = 1_u256;
    let dependency_url = 'https://github.com/test/repo';
    let metadata_hash = 0x5678_felt252;
    let metadata_uri = 'ipfs://QmTest';

    // Create receipt and get ID
    let receipt_id = dispatcher.create_receipt(
        workflow_id,
        dependency_url,
        metadata,
        metadata_hash,
        metadata_uri
    );

    // 3. Check that receipt was successfully created
    // Get current receipt info to confirm receipt exists
    let (_details, _) = dispatcher.get_receipt_details(receipt_id);

    // 4. Update transaction hash
    let new_tx_hash = 0xABCD_felt252; 
    dispatcher.update_tx_hash(receipt_id, new_tx_hash);

    // 5. Check receipt again to confirm the update was successful
    let (_updated_details, _) = dispatcher.get_receipt_details(receipt_id);
}

#[test]
#[should_panic(expected: 'Receipt ID cannot be zero')]
fn test_update_tx_hash_with_zero_id() {
    // 1. Deploy the contract
    let declared_contract_wrapper = ResultTrait::expect(declare("ReceiptContract"), 'Declare failed');
    let contract_to_deploy = declared_contract_wrapper.contract_class();
    let mut constructor_calldata = ArrayTrait::new();
    let (contract_address, _): (starknet::ContractAddress, core::array::Span<felt252>) =
        contract_to_deploy.deploy(@constructor_calldata).unwrap_syscall();
    
    let dispatcher = IReceiptDispatcher { contract_address };

    // 2. Try to update receipt with ID 0, should raise an error
    dispatcher.update_tx_hash(0_u256, 0xABCD_felt252);
}

#[test]
#[should_panic(expected: 'Tx hash cannot be empty')]
fn test_update_tx_hash_with_empty_hash() {
    // 1. Deploy the contract
    let declared_contract_wrapper = ResultTrait::expect(declare("ReceiptContract"), 'Declare failed');
    let contract_to_deploy = declared_contract_wrapper.contract_class();
    let mut constructor_calldata = ArrayTrait::new();
    let (contract_address, _): (starknet::ContractAddress, core::array::Span<felt252>) =
        contract_to_deploy.deploy(@constructor_calldata).unwrap_syscall();
    
    let dispatcher = IReceiptDispatcher { contract_address };

    // 2. First create a receipt
    let receipt_id = dispatcher.create_receipt(
        1_u256,
        'https://github.com/test/repo',
        ReceiptMetadata { name: 'test', version: '1.0', author: 'author', license: 'MIT' },
        0x1234_felt252,
        'ipfs://test'
    );

    // 3. Try to update with empty hash, should raise an error
    dispatcher.update_tx_hash(receipt_id, 0);
}

#[test]
#[should_panic(expected: 'Receipt not found')]
fn test_update_tx_hash_nonexistent() {
    // 1. Deploy the contract
    let declared_contract_wrapper = ResultTrait::expect(declare("ReceiptContract"), 'Declare failed');
    let contract_to_deploy = declared_contract_wrapper.contract_class();
    let mut constructor_calldata = ArrayTrait::new();
    let (contract_address, _): (starknet::ContractAddress, core::array::Span<felt252>) =
        contract_to_deploy.deploy(@constructor_calldata).unwrap_syscall();
    
    let dispatcher = IReceiptDispatcher { contract_address };

    // 2. Try to update non-existent receipt, should raise an error
    dispatcher.update_tx_hash(999_u256, 0xABCD_felt252);
}
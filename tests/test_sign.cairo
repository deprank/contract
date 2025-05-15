// SPDX-License-Identifier: Apache-2.0

use core::array::ArrayTrait;
use core::result::ResultTrait;
use starknet::SyscallResultTrait;

use snforge_std::{declare, ContractClassTrait, DeclareResultTrait, DeclareResult, ContractClass};

use contract::sign::{ISignDispatcher, ISignDispatcherTrait};

#[test]
fn test_contract_deployment() {
    // 1. Declare the contract and get DeclareResult
    let declared_contract_wrapper: DeclareResult =
        ResultTrait::expect(declare("SignContract"), 'Declare failed');

    // 2. Get ContractClass from DeclareResult
    let contract_to_deploy: @ContractClass = declared_contract_wrapper.contract_class();

    // 3. Prepare constructor parameters
    let mut constructor_calldata = ArrayTrait::new();

    // 4. Deploy the contract and destructure the result
    let (contract_address, _returned_data): (starknet::ContractAddress, core::array::Span<felt252>) =
        contract_to_deploy.deploy(@constructor_calldata).unwrap_syscall();

    // 5. Create a dispatcher
    let _dispatcher = ISignDispatcher { contract_address };

    // 6. Assert that contract was successfully deployed
    let zero_address: starknet::ContractAddress = 0.try_into().unwrap();
    assert(contract_address != zero_address, 'Contract deployment failed');
}

#[test]
#[should_panic(expected: 'Workflow ID cannot be zero')]
fn test_create_sign_with_zero_workflow_id() {
    // 1. Deploy the contract
    let declared_contract_wrapper = ResultTrait::expect(declare("SignContract"), 'Declare failed');
    let contract_to_deploy = declared_contract_wrapper.contract_class();
    let mut constructor_calldata = ArrayTrait::new();
    let (contract_address, _): (starknet::ContractAddress, core::array::Span<felt252>) =
        contract_to_deploy.deploy(@constructor_calldata).unwrap_syscall();
    
    let dispatcher = ISignDispatcher { contract_address };

    // 2. Try to create a signature with workflow ID 0
    let zero_workflow_id = 0_u256;
    let inquire_id = 1_u256;
    let signer: starknet::ContractAddress = 0x123.try_into().unwrap();
    let signature_hash = 0xABCD_felt252;
    
    dispatcher.create_sign(
        zero_workflow_id,
        inquire_id,
        signer,
        signature_hash
    );
}

#[test]
#[should_panic(expected: 'Inquire ID cannot be zero')]
fn test_create_sign_with_zero_inquire_id() {
    // 1. Deploy the contract
    let declared_contract_wrapper = ResultTrait::expect(declare("SignContract"), 'Declare failed');
    let contract_to_deploy = declared_contract_wrapper.contract_class();
    let mut constructor_calldata = ArrayTrait::new();
    let (contract_address, _): (starknet::ContractAddress, core::array::Span<felt252>) =
        contract_to_deploy.deploy(@constructor_calldata).unwrap_syscall();
    
    let dispatcher = ISignDispatcher { contract_address };

    // 2. Try to create a signature with inquire ID 0
    let workflow_id = 1_u256;
    let zero_inquire_id = 0_u256;
    let signer: starknet::ContractAddress = 0x123.try_into().unwrap();
    let signature_hash = 0xABCD_felt252;
    
    dispatcher.create_sign(
        workflow_id,
        zero_inquire_id,
        signer,
        signature_hash
    );
}

#[test]
#[should_panic(expected: 'Invalid signer address')]
fn test_create_sign_with_invalid_signer() {
    // 1. Deploy the contract
    let declared_contract_wrapper = ResultTrait::expect(declare("SignContract"), 'Declare failed');
    let contract_to_deploy = declared_contract_wrapper.contract_class();
    let mut constructor_calldata = ArrayTrait::new();
    let (contract_address, _): (starknet::ContractAddress, core::array::Span<felt252>) =
        contract_to_deploy.deploy(@constructor_calldata).unwrap_syscall();
    
    let dispatcher = ISignDispatcher { contract_address };

    // 2. Try to create a signature with zero signer address
    let workflow_id = 1_u256;
    let inquire_id = 1_u256;
    let zero_address: starknet::ContractAddress = 0.try_into().unwrap();
    let signature_hash = 0xABCD_felt252;
    
    dispatcher.create_sign(
        workflow_id,
        inquire_id,
        zero_address,
        signature_hash
    );
}

#[test]
#[should_panic(expected: 'Signature hash cannot be empty')]
fn test_create_sign_with_empty_signature_hash() {
    // 1. Deploy the contract
    let declared_contract_wrapper = ResultTrait::expect(declare("SignContract"), 'Declare failed');
    let contract_to_deploy = declared_contract_wrapper.contract_class();
    let mut constructor_calldata = ArrayTrait::new();
    let (contract_address, _): (starknet::ContractAddress, core::array::Span<felt252>) =
        contract_to_deploy.deploy(@constructor_calldata).unwrap_syscall();
    
    let dispatcher = ISignDispatcher { contract_address };

    // 2. Try to create a signature with empty signature hash
    let workflow_id = 1_u256;
    let inquire_id = 1_u256;
    let signer: starknet::ContractAddress = 0x123.try_into().unwrap();
    let empty_signature_hash = 0;
    
    dispatcher.create_sign(
        workflow_id,
        inquire_id,
        signer,
        empty_signature_hash
    );
}

#[test]
#[should_panic(expected: 'Caller must be the signer')]
fn test_create_sign_with_different_caller() {
    // 1. Deploy the contract
    let declared_contract_wrapper = ResultTrait::expect(declare("SignContract"), 'Declare failed');
    let contract_to_deploy = declared_contract_wrapper.contract_class();
    let mut constructor_calldata = ArrayTrait::new();
    let (contract_address, _): (starknet::ContractAddress, core::array::Span<felt252>) =
        contract_to_deploy.deploy(@constructor_calldata).unwrap_syscall();
    
    let dispatcher = ISignDispatcher { contract_address };

    // 2. Try to create a signature where caller is not signer
    // Note: Since we can't set the caller without prank, this test relies on the default caller
    //       being different from the signer address we specify
    let workflow_id = 1_u256;
    let inquire_id = 1_u256;
    let signer: starknet::ContractAddress = 0x123.try_into().unwrap();
    let signature_hash = 0xABCD_felt252;
    
    dispatcher.create_sign(
        workflow_id,
        inquire_id,
        signer,
        signature_hash
    );
}

#[test]
#[should_panic(expected: 'Invalid sign ID')]
fn test_get_sign_details_with_zero_id() {
    // 1. Deploy the contract
    let declared_contract_wrapper = ResultTrait::expect(declare("SignContract"), 'Declare failed');
    let contract_to_deploy = declared_contract_wrapper.contract_class();
    let mut constructor_calldata = ArrayTrait::new();
    let (contract_address, _): (starknet::ContractAddress, core::array::Span<felt252>) =
        contract_to_deploy.deploy(@constructor_calldata).unwrap_syscall();
    
    let dispatcher = ISignDispatcher { contract_address };

    // 2. Try to get signature details with ID 0
    dispatcher.get_sign_details(0_u256);
}

#[test]
#[should_panic(expected: 'Sign does not exist')]
fn test_get_sign_details_nonexistent() {
    // 1. Deploy the contract
    let declared_contract_wrapper = ResultTrait::expect(declare("SignContract"), 'Declare failed');
    let contract_to_deploy = declared_contract_wrapper.contract_class();
    let mut constructor_calldata = ArrayTrait::new();
    let (contract_address, _): (starknet::ContractAddress, core::array::Span<felt252>) =
        contract_to_deploy.deploy(@constructor_calldata).unwrap_syscall();
    
    let dispatcher = ISignDispatcher { contract_address };

    // 2. Try to get non-existent signature details
    dispatcher.get_sign_details(999_u256);
}

#[test]
#[should_panic(expected: 'Invalid inquire ID')]
fn test_get_sign_by_inquire_with_zero_id() {
    // 1. Deploy the contract
    let declared_contract_wrapper = ResultTrait::expect(declare("SignContract"), 'Declare failed');
    let contract_to_deploy = declared_contract_wrapper.contract_class();
    let mut constructor_calldata = ArrayTrait::new();
    let (contract_address, _): (starknet::ContractAddress, core::array::Span<felt252>) =
        contract_to_deploy.deploy(@constructor_calldata).unwrap_syscall();
    
    let dispatcher = ISignDispatcher { contract_address };

    // 2. Try to get signature by inquire with ID 0
    dispatcher.get_sign_by_inquire(0_u256);
}

#[test]
fn test_get_sign_by_inquire_nonexistent() {
    // 1. Deploy the contract
    let declared_contract_wrapper = ResultTrait::expect(declare("SignContract"), 'Declare failed');
    let contract_to_deploy = declared_contract_wrapper.contract_class();
    let mut constructor_calldata = ArrayTrait::new();
    let (contract_address, _): (starknet::ContractAddress, core::array::Span<felt252>) =
        contract_to_deploy.deploy(@constructor_calldata).unwrap_syscall();
    
    let dispatcher = ISignDispatcher { contract_address };

    // 2. Get signature for non-existent inquire (should return 0, not throw error)
    let sign_id = dispatcher.get_sign_by_inquire(999_u256);
    
    // 3. Verify that returned sign_id is 0 for non-existent inquire
    assert(sign_id == 0_u256, 'ID should be 0');
} 
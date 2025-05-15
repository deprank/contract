// SPDX-License-Identifier: Apache-2.0

use core::array::ArrayTrait;
use core::result::ResultTrait;
use starknet::SyscallResultTrait;

use snforge_std::{declare, ContractClassTrait, DeclareResultTrait, DeclareResult, ContractClass};

use contract::allocation::{IAllocationDispatcher, IAllocationDispatcherTrait};

#[test]
fn test_contract_deployment() {
    // 1. Declare the contract and get DeclareResult
    let declared_contract_wrapper: DeclareResult =
        ResultTrait::expect(declare("AllocationContract"), 'Declare failed');

    // 2. Get ContractClass from DeclareResult
    let contract_to_deploy: @ContractClass = declared_contract_wrapper.contract_class();

    // 3. Prepare constructor parameters
    let mut constructor_calldata = ArrayTrait::new();

    // 4. Deploy the contract and destructure the result
    let (contract_address, _returned_data): (starknet::ContractAddress, core::array::Span<felt252>) =
        contract_to_deploy.deploy(@constructor_calldata).unwrap_syscall();

    // 5. Create a dispatcher
    let _dispatcher = IAllocationDispatcher { contract_address };

    // 6. Assert that contract was successfully deployed
    let zero_address: starknet::ContractAddress = 0.try_into().unwrap();
    assert(contract_address != zero_address, 'Contract deployment failed');
}

#[test]
#[should_panic(expected: 'Sign ID cannot be zero')]
fn test_create_allocation_with_zero_sign_id() {
    // 1. Deploy the contract
    let declared_contract_wrapper = ResultTrait::expect(declare("AllocationContract"), 'Declare failed');
    let contract_to_deploy = declared_contract_wrapper.contract_class();
    let mut constructor_calldata = ArrayTrait::new();
    let (contract_address, _): (starknet::ContractAddress, core::array::Span<felt252>) =
        contract_to_deploy.deploy(@constructor_calldata).unwrap_syscall();
    
    let dispatcher = IAllocationDispatcher { contract_address };

    // 2. Try to create an allocation with sign ID 0
    let workflow_id = 1_u256;
    let zero_sign_id = 0_u256;
    let recipient: starknet::ContractAddress = 0x123.try_into().unwrap();
    let amount = 1000_u256;
    let token_address: starknet::ContractAddress = 0x456.try_into().unwrap();
    
    dispatcher.create_allocation(
        workflow_id,
        zero_sign_id,
        recipient,
        amount,
        token_address
    );
}

#[test]
#[should_panic(expected: 'Amount cannot be zero')]
fn test_create_allocation_with_zero_amount() {
    // 1. Deploy the contract
    let declared_contract_wrapper = ResultTrait::expect(declare("AllocationContract"), 'Declare failed');
    let contract_to_deploy = declared_contract_wrapper.contract_class();
    let mut constructor_calldata = ArrayTrait::new();
    let (contract_address, _): (starknet::ContractAddress, core::array::Span<felt252>) =
        contract_to_deploy.deploy(@constructor_calldata).unwrap_syscall();
    
    let dispatcher = IAllocationDispatcher { contract_address };

    // 2. Try to create an allocation with zero amount
    let workflow_id = 1_u256;
    let sign_id = 1_u256;
    let recipient: starknet::ContractAddress = 0x123.try_into().unwrap();
    let zero_amount = 0_u256;
    let token_address: starknet::ContractAddress = 0x456.try_into().unwrap();
    
    dispatcher.create_allocation(
        workflow_id,
        sign_id,
        recipient,
        zero_amount,
        token_address
    );
}

#[test]
#[should_panic(expected: 'Invalid recipient address')]
fn test_create_allocation_with_invalid_recipient() {
    // 1. Deploy the contract
    let declared_contract_wrapper = ResultTrait::expect(declare("AllocationContract"), 'Declare failed');
    let contract_to_deploy = declared_contract_wrapper.contract_class();
    let mut constructor_calldata = ArrayTrait::new();
    let (contract_address, _): (starknet::ContractAddress, core::array::Span<felt252>) =
        contract_to_deploy.deploy(@constructor_calldata).unwrap_syscall();
    
    let dispatcher = IAllocationDispatcher { contract_address };

    // 2. Try to create an allocation with zero recipient address
    let workflow_id = 1_u256;
    let sign_id = 1_u256;
    let zero_address: starknet::ContractAddress = 0.try_into().unwrap();
    let amount = 1000_u256;
    let token_address: starknet::ContractAddress = 0x456.try_into().unwrap();
    
    dispatcher.create_allocation(
        workflow_id,
        sign_id,
        zero_address,
        amount,
        token_address
    );
}

#[test]
#[should_panic(expected: 'Invalid token address')]
fn test_create_allocation_with_invalid_token_address() {
    // 1. Deploy the contract
    let declared_contract_wrapper = ResultTrait::expect(declare("AllocationContract"), 'Declare failed');
    let contract_to_deploy = declared_contract_wrapper.contract_class();
    let mut constructor_calldata = ArrayTrait::new();
    let (contract_address, _): (starknet::ContractAddress, core::array::Span<felt252>) =
        contract_to_deploy.deploy(@constructor_calldata).unwrap_syscall();
    
    let dispatcher = IAllocationDispatcher { contract_address };

    // 2. Try to create an allocation with zero token address
    let workflow_id = 1_u256;
    let sign_id = 1_u256;
    let recipient: starknet::ContractAddress = 0x123.try_into().unwrap();
    let amount = 1000_u256;
    let zero_address: starknet::ContractAddress = 0.try_into().unwrap();
    
    dispatcher.create_allocation(
        workflow_id,
        sign_id,
        recipient,
        amount,
        zero_address
    );
}

#[test]
#[should_panic(expected: 'Invalid allocation ID')]
fn test_update_allocation_status_with_zero_id() {
    // 1. Deploy the contract
    let declared_contract_wrapper = ResultTrait::expect(declare("AllocationContract"), 'Declare failed');
    let contract_to_deploy = declared_contract_wrapper.contract_class();
    let mut constructor_calldata = ArrayTrait::new();
    let (contract_address, _): (starknet::ContractAddress, core::array::Span<felt252>) =
        contract_to_deploy.deploy(@constructor_calldata).unwrap_syscall();
    
    let dispatcher = IAllocationDispatcher { contract_address };

    // 2. Try to update allocation status with ID 0
    dispatcher.update_allocation_status(0_u256, 1_felt252); // 1 = executed
}

#[test]
#[should_panic(expected: 'Invalid status value')]
fn test_update_allocation_status_with_invalid_status() {
    // 1. Deploy the contract
    let declared_contract_wrapper = ResultTrait::expect(declare("AllocationContract"), 'Declare failed');
    let contract_to_deploy = declared_contract_wrapper.contract_class();
    let mut constructor_calldata = ArrayTrait::new();
    let (contract_address, _): (starknet::ContractAddress, core::array::Span<felt252>) =
        contract_to_deploy.deploy(@constructor_calldata).unwrap_syscall();
    
    let dispatcher = IAllocationDispatcher { contract_address };

    // 2. Try to update allocation status with invalid status value
    dispatcher.update_allocation_status(1_u256, 3_felt252); // Valid values are 0, 1, 2
}

#[test]
#[should_panic(expected: 'Allocation does not exist')]
fn test_update_allocation_status_nonexistent() {
    // 1. Deploy the contract
    let declared_contract_wrapper = ResultTrait::expect(declare("AllocationContract"), 'Declare failed');
    let contract_to_deploy = declared_contract_wrapper.contract_class();
    let mut constructor_calldata = ArrayTrait::new();
    let (contract_address, _): (starknet::ContractAddress, core::array::Span<felt252>) =
        contract_to_deploy.deploy(@constructor_calldata).unwrap_syscall();
    
    let dispatcher = IAllocationDispatcher { contract_address };

    // 2. Try to update allocation status for non-existent allocation
    dispatcher.update_allocation_status(999_u256, 1_felt252);
}

#[test]
fn test_get_allocation_details() {
    // Since we can't create an allocation without setting the caller identity via prank,
    // we can't fully test this function, but can test that it doesn't throw an error
    
    // 1. Deploy the contract
    let declared_contract_wrapper = ResultTrait::expect(declare("AllocationContract"), 'Declare failed');
    let contract_to_deploy = declared_contract_wrapper.contract_class();
    let mut constructor_calldata = ArrayTrait::new();
    let (contract_address, _): (starknet::ContractAddress, core::array::Span<felt252>) =
        contract_to_deploy.deploy(@constructor_calldata).unwrap_syscall();
    
    let dispatcher = IAllocationDispatcher { contract_address };

    // 2. Get allocation details for ID 1 (should return default values)
    // Just checking that the function call succeeds, not accessing private fields
    let _details = dispatcher.get_allocation_details(1_u256);
}

#[test]
fn test_get_allocation_by_sign() {
    // 1. Deploy the contract
    let declared_contract_wrapper = ResultTrait::expect(declare("AllocationContract"), 'Declare failed');
    let contract_to_deploy = declared_contract_wrapper.contract_class();
    let mut constructor_calldata = ArrayTrait::new();
    let (contract_address, _): (starknet::ContractAddress, core::array::Span<felt252>) =
        contract_to_deploy.deploy(@constructor_calldata).unwrap_syscall();
    
    let dispatcher = IAllocationDispatcher { contract_address };

    // 2. Get allocation for a sign that doesn't have an allocation yet
    let allocation_id = dispatcher.get_allocation_by_sign(999_u256);
    
    // 3. Verify that returned allocation_id is 0 for a sign without allocation
    assert(allocation_id == 0_u256, 'ID should be 0');
} 
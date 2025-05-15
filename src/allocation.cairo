// SPDX-License-Identifier: Apache-2.0

use starknet::{ContractAddress, get_block_timestamp, get_tx_info};
use core::array::ArrayTrait;
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

/// Allocation合约接口
#[starknet::interface]
pub trait IAllocation<TContractState> {
    /// 创建分配记录
    fn create_allocation(
        ref self: TContractState,
        workflow_id: u256,
        sign_id: u256,
        recipient: ContractAddress,
        amount: u256,
        token_address: ContractAddress
    ) -> u256;

    /// 更新分配状态
    fn update_allocation_status(ref self: TContractState, allocation_id: u256, status: felt252) -> bool;

    /// 获取分配详情
    fn get_allocation_details(self: @TContractState, allocation_id: u256) -> AllocationDetails;

    /// 通过签名ID获取分配ID
    fn get_allocation_by_sign(self: @TContractState, sign_id: u256) -> u256;
}

/// Allocation合约实现
#[starknet::contract]
mod AllocationContract {
    use super::{ContractAddress, get_tx_info, ArrayTrait};
    use super::{AllocationDetails};
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
            // 获取当前交易信息
            let tx_info = get_tx_info().unbox();
            let tx_hash = tx_info.transaction_hash;
            
            // 生成新的分配ID
            let allocation_id = self.allocation_count.read() + 1_u256;
            self.allocation_count.write(allocation_id);
            
            // 存储分配信息
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
            
            // 记录sign_id到allocation_id的映射
            self.sign_to_allocation.entry(sign_id).write(allocation_id);
            
            // 触发事件
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
            // 这里应该添加权限检查，确保只有授权方可以调用
            
            // 获取当前交易信息
            let tx_info = get_tx_info().unbox();
            let tx_hash = tx_info.transaction_hash;
            
            // 更新分配状态
            let allocation = self.allocations.entry(allocation_id).read();
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
            
            // 触发事件
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

    // 内部函数
    #[generate_trait]
    impl AllocationInternalImpl of AllocationInternalTrait {
        // 标记分配已处理（由多签钱包回调或管理员调用）
        fn mark_processed(ref self: ContractState, allocation_id: u256) {
            // 这里应该添加权限检查，确保只有授权方可以调用
            
            // 获取当前交易信息
            let tx_info = get_tx_info().unbox();
            let tx_hash = tx_info.transaction_hash;
            
            // 更新分配状态
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
            
            // 触发事件
            self.emit(AllocationProcessed {
                allocation_id,
                tx_hash,
            });
        }
    }
} 
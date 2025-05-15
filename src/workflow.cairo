// SPDX-License-Identifier: Apache-2.0

use starknet::{ContractAddress, get_block_timestamp, get_tx_info};
use core::array::ArrayTrait;
use core::option::OptionTrait;
use core::box::BoxTrait;
use core::option::Option;
use starknet::storage::{StoragePointerReadAccess, StoragePointerWriteAccess, StoragePathEntry, Map};

#[derive(Drop, Serde, starknet::Store)]
pub struct WorkflowDetails {
    owner: ContractAddress,
    wallet_address: ContractAddress, // Associated multisig wallet address
    status: felt252, // 0: created, 1: in_progress, 2: completed
    created_at: u64,
    last_updated_at: u64,
}

#[derive(Drop, Serde, starknet::Store)]
pub struct DependencyDetails {
    name: felt252,          // Dependency name or ID
    repository_url: felt252, // Repository URL
    license: felt252,       // License
    metadata_json: felt252, // JSON formatted additional data (contributor info, allocation ratios, etc.)
    status: felt252,        // 0: created, 1: in_progress, 2: completed
    created_at: u64,
    last_updated_at: u64,
}

#[derive(Drop, Serde, starknet::Store)]
pub struct StepDetails {
    step_type: felt252, // 1: receipt, 2: inquire, 3: sign, 4: allocation
    tx_hash: felt252,
    related_entity_id: u256, // Related entity ID (receipt_id, inquire_id, etc.)
    timestamp: u64,
    prev_step_index: u256, // Previous step index, used for linking
}

/// Workflow contract interface
#[starknet::interface]
pub trait IWorkflow<TContractState> {
    /// Create workflow
    fn create_workflow(ref self: TContractState, github_owner: felt252, wallet_address: ContractAddress) -> (felt252, u256);

    /// Create dependency
    fn create_dependency(
        ref self: TContractState, 
        github_owner: felt252, 
        workflow_id: u256, 
        name: felt252,
        repository_url: felt252,
        license: felt252,
        metadata_json: felt252
    ) -> u256;

    /// Add step
    fn add_step(
        ref self: TContractState,
        github_owner: felt252,
        workflow_id: u256,
        dependency_index: u256,
        step_type: felt252,
        tx_hash: felt252,
        related_entity_id: u256
    ) -> u256;

    /// Complete dependency
    fn finish_dependency(ref self: TContractState, github_owner: felt252, workflow_id: u256, dependency_index: u256) -> bool;

    /// Complete workflow
    fn finish_workflow(ref self: TContractState, github_owner: felt252, workflow_id: u256) -> bool;

    /// Get workflow status
    fn get_workflow_status(self: @TContractState, github_owner: felt252, workflow_id: u256) -> WorkflowDetails;

    /// Get workflow dependencies
    fn get_dependencies(self: @TContractState, github_owner: felt252, workflow_id: u256) -> Array<DependencyDetails>;

    /// Get dependency steps
    fn get_steps(self: @TContractState, github_owner: felt252, workflow_id: u256, dependency_index: u256) -> Array<StepDetails>;

    /// Get step by transaction hash
    fn get_step_by_tx_hash(self: @TContractState, tx_hash: felt252) -> Option<(felt252, u256, u256, u256)>;

    /// Get complete transaction chain
    fn get_complete_transaction_chain(self: @TContractState, github_owner: felt252, workflow_id: u256, dependency_index: u256) -> Array<felt252>;
    
    /// Get user workflow count
    fn get_workflow_count(self: @TContractState, github_owner: felt252) -> u256;
    
    /// Get all user workflows
    fn get_all_workflows(self: @TContractState, github_owner: felt252) -> Array<(u256, WorkflowDetails)>;
    
    /// Bind multisig wallet address to workflow
    fn bind_wallet_address(ref self: TContractState, github_owner: felt252, workflow_id: u256, wallet_address: ContractAddress) -> bool;
    
    /// Unbind multisig wallet address
    fn unbind_wallet_address(ref self: TContractState, github_owner: felt252, workflow_id: u256) -> bool;
    
    /// Change multisig wallet address
    fn change_wallet_address(ref self: TContractState, github_owner: felt252, workflow_id: u256, new_wallet_address: ContractAddress) -> bool;
}

/// Workflow contract implementation
#[starknet::contract]
mod WorkflowContract {
    use super::{ContractAddress, get_tx_info, ArrayTrait, BoxTrait};
    use super::{WorkflowDetails, DependencyDetails, StepDetails, Option};
    use starknet::storage::{StoragePointerReadAccess, StoragePointerWriteAccess, StoragePathEntry, Map};
    use starknet::get_block_timestamp;
    use core::option::OptionTrait;

    #[storage]
    struct Storage {
        // Workflow related storage
        workflow_count: Map<felt252, u256>, // github_owner -> workflow_count
        workflows: Map<(felt252, u256), WorkflowDetails>, // (github_owner, workflow_id) -> WorkflowDetails
        
        // Dependency related storage
        workflow_dependency_count: Map<(felt252, u256), u256>, // (github_owner, workflow_id) -> dependency_count
        dependencies: Map<(felt252, u256, u256), DependencyDetails>, // (github_owner, workflow_id, dependency_index) -> DependencyDetails
        
        // Step related storage
        workflow_steps_count: Map<(felt252, u256, u256), u256>, // (github_owner, workflow_id, dependency_index) -> step_count
        workflow_steps: Map<(felt252, u256, u256, u256), StepDetails>, // (github_owner, workflow_id, dependency_index, step_index) -> StepDetails
        
        // Transaction hash mapping
        tx_hash_to_step: Map<felt252, (felt252, u256, u256, u256)>, // tx_hash -> (github_owner, workflow_id, dependency_index, step_index)
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        WorkflowCreated: WorkflowCreated,
        DependencyCreated: DependencyCreated,
        StepAdded: StepAdded,
        DependencyFinished: DependencyFinished,
        WorkflowFinished: WorkflowFinished,
        WalletAddressBound: WalletAddressBound,
        WalletAddressUnbound: WalletAddressUnbound,
        WalletAddressChanged: WalletAddressChanged,
    }

    #[derive(Drop, starknet::Event)]
    struct WorkflowCreated {
        github_owner: felt252,
        workflow_id: u256,
        wallet_address: ContractAddress,
        tx_hash: felt252,
    }

    #[derive(Drop, starknet::Event)]
    struct DependencyCreated {
        github_owner: felt252,
        workflow_id: u256,
        dependency_index: u256,
        name: felt252,
        repository_url: felt252,
        license: felt252,
        metadata_json: felt252,
        tx_hash: felt252,
    }

    #[derive(Drop, starknet::Event)]
    struct StepAdded {
        github_owner: felt252,
        workflow_id: u256,
        dependency_index: u256,
        step_index: u256,
        step_type: felt252,
        tx_hash: felt252,
        related_entity_id: u256,
        prev_step_index: u256,
    }

    #[derive(Drop, starknet::Event)]
    struct DependencyFinished {
        github_owner: felt252,
        workflow_id: u256,
        dependency_index: u256,
        tx_hash: felt252,
    }

    #[derive(Drop, starknet::Event)]
    struct WorkflowFinished {
        github_owner: felt252,
        workflow_id: u256,
        tx_hash: felt252,
    }
    
    #[derive(Drop, starknet::Event)]
    struct WalletAddressBound {
        github_owner: felt252,
        workflow_id: u256,
        wallet_address: ContractAddress,
        tx_hash: felt252,
    }
    
    #[derive(Drop, starknet::Event)]
    struct WalletAddressUnbound {
        github_owner: felt252,
        workflow_id: u256,
        previous_wallet_address: ContractAddress,
        tx_hash: felt252,
    }
    
    #[derive(Drop, starknet::Event)]
    struct WalletAddressChanged {
        github_owner: felt252,
        workflow_id: u256,
        previous_wallet_address: ContractAddress,
        new_wallet_address: ContractAddress,
        tx_hash: felt252,
    }

    #[abi(embed_v0)]
    impl WorkflowImpl of super::IWorkflow<ContractState> {
        fn create_workflow(ref self: ContractState, github_owner: felt252, wallet_address: ContractAddress) -> (felt252, u256) {
            // Get current transaction information
            let tx_info = get_tx_info().unbox();
            let tx_hash = tx_info.transaction_hash;
            
            // Generate new workflow ID
            let workflow_id = self.workflow_count.entry(github_owner).read() + 1_u256;
            self.workflow_count.entry(github_owner).write(workflow_id);
            
            let _current_time = get_block_timestamp();
            
            // Store workflow information
            self.workflows.entry((github_owner, workflow_id)).write(
                WorkflowDetails {
                    owner: starknet::get_caller_address(),
                    wallet_address,
                    status: 0, // Initial status: created
                    created_at: _current_time,
                    last_updated_at: _current_time,
                }
            );
            
            // Initialize dependency counter
            self.workflow_dependency_count.entry((github_owner, workflow_id)).write(0_u256);
            
            // Trigger event
            self.emit(WorkflowCreated {
                github_owner,
                workflow_id,
                wallet_address,
                tx_hash,
            });
            
            (github_owner, workflow_id)
        }
        
        fn create_dependency(
            ref self: ContractState, 
            github_owner: felt252, 
            workflow_id: u256, 
            name: felt252,
            repository_url: felt252,
            license: felt252,
            metadata_json: felt252
        ) -> u256 {
            // Get current transaction information
            let tx_info = get_tx_info().unbox();
            let tx_hash = tx_info.transaction_hash;
            
            // Check if workflow exists and is not completed
            let workflow = self.workflows.entry((github_owner, workflow_id)).read();
            assert(workflow.status != 2, 'Workflow already completed');
            
            // Generate new dependency ID
            let dependency_index = self.workflow_dependency_count.entry((github_owner, workflow_id)).read() + 1_u256;
            self.workflow_dependency_count.entry((github_owner, workflow_id)).write(dependency_index);
            
            let _current_time = get_block_timestamp();
            
            // Store dependency information
            self.dependencies.entry((github_owner, workflow_id, dependency_index)).write(
                DependencyDetails {
                    name,
                    repository_url,
                    license,
                    metadata_json,
                    status: 0, // Initial status: created
                    created_at: _current_time,
                    last_updated_at: _current_time,
                }
            );
            
            // Initialize step counter
            self.workflow_steps_count.entry((github_owner, workflow_id, dependency_index)).write(0_u256);
            
            // Trigger event
            self.emit(DependencyCreated {
                github_owner,
                workflow_id,
                dependency_index,
                name,
                repository_url,
                license,
                metadata_json,
                tx_hash,
            });
            
            dependency_index
        }
        
        fn add_step(
            ref self: ContractState,
            github_owner: felt252,
            workflow_id: u256,
            dependency_index: u256,
            step_type: felt252,
            tx_hash: felt252,
            related_entity_id: u256
        ) -> u256 {
            // Check if workflow exists and is not completed
            let workflow = self.workflows.entry((github_owner, workflow_id)).read();
            assert(workflow.status != 2, 'Workflow already completed');
            
            // Check if dependency exists and is not completed
            let dependency = self.dependencies.entry((github_owner, workflow_id, dependency_index)).read();
            assert(dependency.status != 2, 'Dependency already completed');
            
            // If workflow is in created status, update to in_progress
            if workflow.status == 0 {
                let _updated_workflow = WorkflowDetails {
                    owner: workflow.owner,
                    wallet_address: workflow.wallet_address,
                    status: 1, // in_progress
                    created_at: workflow.created_at,
                    last_updated_at: get_block_timestamp(),
                };
                self.workflows.entry((github_owner, workflow_id)).write(_updated_workflow);
            }
            
            // If dependency is in created status, update to in_progress
            if dependency.status == 0 {
                let _updated_dependency = DependencyDetails {
                    name: dependency.name,
                    repository_url: dependency.repository_url,
                    license: dependency.license,
                    metadata_json: dependency.metadata_json,
                    status: 1, // in_progress
                    created_at: dependency.created_at,
                    last_updated_at: get_block_timestamp(),
                };
                self.dependencies.entry((github_owner, workflow_id, dependency_index)).write(_updated_dependency);
            }
            
            // Get current step index
            let step_index = self.workflow_steps_count.entry((github_owner, workflow_id, dependency_index)).read() + 1_u256;
            self.workflow_steps_count.entry((github_owner, workflow_id, dependency_index)).write(step_index);
            
            // Get previous step index
            let prev_step_index = if step_index == 1_u256 {
                0_u256 // First step has no previous step
            } else {
                step_index - 1_u256
            };
            
            // Store step information
            self.workflow_steps.entry((github_owner, workflow_id, dependency_index, step_index)).write(
                StepDetails {
                    step_type,
                    tx_hash,
                    related_entity_id,
                    timestamp: get_block_timestamp(),
                    prev_step_index,
                }
            );
            
            // Record transaction hash to step mapping
            self.tx_hash_to_step.entry(tx_hash).write((github_owner, workflow_id, dependency_index, step_index));
            
            // Trigger event
            self.emit(StepAdded {
                github_owner,
                workflow_id,
                dependency_index,
                step_index,
                step_type,
                tx_hash,
                related_entity_id,
                prev_step_index,
            });
            
            step_index
        }
        
        fn finish_dependency(ref self: ContractState, github_owner: felt252, workflow_id: u256, dependency_index: u256) -> bool {
            // Get current transaction information
            let tx_info = get_tx_info().unbox();
            let tx_hash = tx_info.transaction_hash;
            
            // Check if dependency exists and is not completed
            let dependency = self.dependencies.entry((github_owner, workflow_id, dependency_index)).read();
            assert(dependency.status != 2, 'Dependency already completed');
            
            // Update dependency status
            let _updated_dependency = DependencyDetails {
                name: dependency.name,
                repository_url: dependency.repository_url,
                license: dependency.license,
                metadata_json: dependency.metadata_json,
                status: 2, // completed
                created_at: dependency.created_at,
                last_updated_at: get_block_timestamp(),
            };
            self.dependencies.entry((github_owner, workflow_id, dependency_index)).write(_updated_dependency);
            
            // Trigger event
            self.emit(DependencyFinished {
                github_owner,
                workflow_id,
                dependency_index,
                tx_hash,
            });
            
            true
        }
        
        fn finish_workflow(ref self: ContractState, github_owner: felt252, workflow_id: u256) -> bool {
            // Get current transaction information
            let tx_info = get_tx_info().unbox();
            let tx_hash = tx_info.transaction_hash;
            
            // Check if workflow exists and is not completed
            let workflow = self.workflows.entry((github_owner, workflow_id)).read();
            assert(workflow.status != 2, 'Workflow already completed');
            
            // Check if all dependencies are completed
            let dependency_count = self.workflow_dependency_count.entry((github_owner, workflow_id)).read();
            let mut i: u256 = 1_u256;
            loop {
                if i > dependency_count {
                    break;
                }
                let dependency = self.dependencies.entry((github_owner, workflow_id, i)).read();
                assert(dependency.status == 2, 'Not all dependencies completed');
                i += 1_u256;
            };
            
            // Update workflow status
            let _updated_workflow = WorkflowDetails {
                owner: workflow.owner,
                wallet_address: workflow.wallet_address,
                status: 2, // completed
                created_at: workflow.created_at,
                last_updated_at: get_block_timestamp(),
            };
            self.workflows.entry((github_owner, workflow_id)).write(_updated_workflow);
            
            // Trigger event
            self.emit(WorkflowFinished {
                github_owner,
                workflow_id,
                tx_hash,
            });
            
            true
        }
        
        fn get_workflow_status(self: @ContractState, github_owner: felt252, workflow_id: u256) -> WorkflowDetails {
            self.workflows.entry((github_owner, workflow_id)).read()
        }
        
        fn get_dependencies(self: @ContractState, github_owner: felt252, workflow_id: u256) -> Array<DependencyDetails> {
            let dependency_count = self.workflow_dependency_count.entry((github_owner, workflow_id)).read();
            let mut dependencies = ArrayTrait::new();
            
            let mut i: u256 = 1_u256;
            loop {
                if i > dependency_count {
                    break;
                }
                let dependency = self.dependencies.entry((github_owner, workflow_id, i)).read();
                dependencies.append(dependency);
                i += 1_u256;
            };
            
            dependencies
        }
        
        fn get_steps(self: @ContractState, github_owner: felt252, workflow_id: u256, dependency_index: u256) -> Array<StepDetails> {
            let steps_count = self.workflow_steps_count.entry((github_owner, workflow_id, dependency_index)).read();
            let mut steps = ArrayTrait::new();
            
            let mut i: u256 = 1_u256;
            loop {
                if i > steps_count {
                    break;
                }
                let step = self.workflow_steps.entry((github_owner, workflow_id, dependency_index, i)).read();
                steps.append(step);
                i += 1_u256;
            };
            
            steps
        }
        
        fn get_step_by_tx_hash(self: @ContractState, tx_hash: felt252) -> Option<(felt252, u256, u256, u256)> {
            let result = self.tx_hash_to_step.entry(tx_hash).read();
            
            // Use pattern matching to access tuple elements
            let (github_owner, workflow_id, _, _) = result;
            if workflow_id == 0_u256 {
                Option::None(())
            } else {
                Option::Some(result)
            }
        }
        
        fn get_complete_transaction_chain(self: @ContractState, github_owner: felt252, workflow_id: u256, dependency_index: u256) -> Array<felt252> {
            let steps_count = self.workflow_steps_count.entry((github_owner, workflow_id, dependency_index)).read();
            let mut tx_chain = ArrayTrait::new();
            
            let mut i: u256 = 1_u256;
            loop {
                if i > steps_count {
                    break;
                }
                let step = self.workflow_steps.entry((github_owner, workflow_id, dependency_index, i)).read();
                tx_chain.append(step.tx_hash);
                i += 1_u256;
            };
            
            tx_chain
        }
        
        fn get_workflow_count(self: @ContractState, github_owner: felt252) -> u256 {
            self.workflow_count.entry(github_owner).read()
        }
        
        fn get_all_workflows(self: @ContractState, github_owner: felt252) -> Array<(u256, WorkflowDetails)> {
            let workflow_count = self.workflow_count.entry(github_owner).read();
            let mut workflows = ArrayTrait::new();
            
            let mut i: u256 = 1_u256;
            loop {
                if i > workflow_count {
                    break;
                }
                let workflow = self.workflows.entry((github_owner, i)).read();
                workflows.append((i, workflow));
                i += 1_u256;
            };
            
            workflows
        }
        
        fn bind_wallet_address(ref self: ContractState, github_owner: felt252, workflow_id: u256, wallet_address: ContractAddress) -> bool {
            // Get current transaction information
            let tx_info = get_tx_info().unbox();
            let tx_hash = tx_info.transaction_hash;
            
            // Check if workflow exists
            let workflow = self.workflows.entry((github_owner, workflow_id)).read();
            assert(workflow.owner != 0.try_into().unwrap(), 'Workflow does not exist');
            
            // Check permissions
            assert(workflow.owner == starknet::get_caller_address(), 'Not authorized');
            
            // Check if wallet address is already bound
            assert(workflow.wallet_address == 0.try_into().unwrap(), 'Wallet address already bound');
            
            // Update workflow wallet address
            let _updated_workflow = WorkflowDetails {
                owner: workflow.owner,
                wallet_address: wallet_address,
                status: workflow.status,
                created_at: workflow.created_at,
                last_updated_at: get_block_timestamp(),
            };
            self.workflows.entry((github_owner, workflow_id)).write(_updated_workflow);
            
            // Trigger event
            self.emit(WalletAddressBound {
                github_owner,
                workflow_id,
                wallet_address,
                tx_hash,
            });
            
            true
        }
        
        fn unbind_wallet_address(ref self: ContractState, github_owner: felt252, workflow_id: u256) -> bool {
            // Get current transaction information
            let tx_info = get_tx_info().unbox();
            let tx_hash = tx_info.transaction_hash;
            
            // Check if workflow exists
            let workflow = self.workflows.entry((github_owner, workflow_id)).read();
            assert(workflow.owner != 0.try_into().unwrap(), 'Workflow does not exist');
            
            // Check permissions
            assert(workflow.owner == starknet::get_caller_address(), 'Not authorized');
            
            // Check if wallet address is bound
            assert(workflow.wallet_address != 0.try_into().unwrap(), 'No wallet address bound');
            
            // Save previous wallet address for event
            let previous_wallet_address = workflow.wallet_address;
            
            // Update workflow wallet address
            let _updated_workflow = WorkflowDetails {
                owner: workflow.owner,
                wallet_address: 0.try_into().unwrap(),
                status: workflow.status,
                created_at: workflow.created_at,
                last_updated_at: get_block_timestamp(),
            };
            self.workflows.entry((github_owner, workflow_id)).write(_updated_workflow);
            
            // Trigger event
            self.emit(WalletAddressUnbound {
                github_owner,
                workflow_id,
                previous_wallet_address,
                tx_hash,
            });
            
            true
        }
        
        fn change_wallet_address(ref self: ContractState, github_owner: felt252, workflow_id: u256, new_wallet_address: ContractAddress) -> bool {
            // Get current transaction information
            let tx_info = get_tx_info().unbox();
            let tx_hash = tx_info.transaction_hash;
            
            // Check if workflow exists
            let workflow = self.workflows.entry((github_owner, workflow_id)).read();
            assert(workflow.owner != 0.try_into().unwrap(), 'Workflow does not exist');
            
            // Check permissions
            assert(workflow.owner == starknet::get_caller_address(), 'Not authorized');
            
            // Check if wallet address is bound
            assert(workflow.wallet_address != 0.try_into().unwrap(), 'No wallet address bound');
            
            // Save previous wallet address for event
            let previous_wallet_address = workflow.wallet_address;
            
            // Check if new address is different from old one
            assert(previous_wallet_address != new_wallet_address, 'New address same as old one');
            
            // Update workflow wallet address
            let _updated_workflow = WorkflowDetails {
                owner: workflow.owner,
                wallet_address: new_wallet_address,
                status: workflow.status,
                created_at: workflow.created_at,
                last_updated_at: get_block_timestamp(),
            };
            self.workflows.entry((github_owner, workflow_id)).write(_updated_workflow);
            
            // Trigger event
            self.emit(WalletAddressChanged {
                github_owner,
                workflow_id,
                previous_wallet_address,
                new_wallet_address,
                tx_hash,
            });
            
            true
        }
    }
}
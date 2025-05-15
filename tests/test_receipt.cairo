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
    // 1. 声明合约并获取DeclareResult
    let declared_contract_wrapper: DeclareResult =
        ResultTrait::expect(declare("ReceiptContract"), 'Declare failed'); // ASCII-Fehlermeldung

    // 2. 从DeclareResult获取ContractClass
    let contract_to_deploy: @ContractClass = declared_contract_wrapper.contract_class();

    // 3. 准备构造函数参数 (dein Vertrag hat keinen Konstruktor, also leer)
    let mut constructor_calldata = ArrayTrait::new();

    // 4. 部署合约并直接解构结果
    let (contract_address, _returned_data): (starknet::ContractAddress, core::array::Span<felt252>) =
        contract_to_deploy.deploy(@constructor_calldata).unwrap_syscall();

    // 5. 创建调度器 (Dispatcher wird hier nicht verwendet, aber das ist okay für einen reinen Deployment-Test)
    let _dispatcher = IReceiptDispatcher { contract_address }; // Mit _ markieren, wenn nicht direkt verwendet

    // 6. 断言合约已成功部署
    let zero_address: starknet::ContractAddress = 0.try_into().unwrap();
    assert(contract_address != zero_address, 'Contract deployment failed'); // ASCII-Fehlermeldung
}

#[test]
fn test_create_receipt() {
    // 1. 声明并部署合约
    let declared_contract_wrapper = ResultTrait::expect(declare("ReceiptContract"), 'Declare failed'); // ASCII
    let contract_to_deploy = declared_contract_wrapper.contract_class();
    let mut constructor_calldata = ArrayTrait::new();
    let (contract_address, _): (starknet::ContractAddress, core::array::Span<felt252>) =
        contract_to_deploy.deploy(@constructor_calldata).unwrap_syscall();

    // 2. 创建调度器
    let dispatcher = IReceiptDispatcher { contract_address };

    // 3. 创建元数据 - Diese Variablen sind korrekt definiert
    let name = 'test-receipt';
    let version = '1.0.0';
    let author = 'test-author';
    let license = 'MIT';

    // 4. 准备数据
    let workflow_id = 1_u256;
    let dependency_url = 'https://github.com/test/repo';
    let metadata_hash = 0x5678_felt252; // Explizit als felt252 markieren ist gute Praxis
    let metadata_uri = 'ipfs://QmTest';

    // 5. 调用create_receipt函数
    // Die Strukturinitialisierung ReceiptMetadata { name, version, author, license }
    // ist korrekt, da die lokalen Variablen dieselben Namen haben wie die Felder.
    let receipt_id = dispatcher.create_receipt(
        workflow_id,
        dependency_url,
        ReceiptMetadata { name, version, author, license },
        metadata_hash,
        metadata_uri
    );

    // 6. 验证receipt_id是否为1
    assert(receipt_id == 1_u256, 'Receipt ID should be 1'); // ASCII-Fehlermeldung
}

#[test]
fn test_get_receipt_details() {
    // 1. 部署合约
    let declared_contract_wrapper = ResultTrait::expect(declare("ReceiptContract"), 'Declare failed');
    let contract_to_deploy = declared_contract_wrapper.contract_class();
    let mut constructor_calldata = ArrayTrait::new();
    let (contract_address, _): (starknet::ContractAddress, core::array::Span<felt252>) =
        contract_to_deploy.deploy(@constructor_calldata).unwrap_syscall();
    
    let dispatcher = IReceiptDispatcher { contract_address };

    // 2. 先创建一个收据
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

    // 创建收据并获取ID
    let receipt_id = dispatcher.create_receipt(
        workflow_id,
        dependency_url,
        metadata,
        metadata_hash,
        metadata_uri
    );

    // 3. 获取收据详情
    let (_, retrieved_metadata) = dispatcher.get_receipt_details(receipt_id);
    
    // 4. 验证元数据
    assert(retrieved_metadata.name == 'test-receipt', 'Wrong metadata name');
    assert(retrieved_metadata.version == '1.0.0', 'Wrong metadata version');
    assert(retrieved_metadata.author == 'test-author', 'Wrong metadata author');
    assert(retrieved_metadata.license == 'MIT', 'Wrong metadata license');
}

#[test]
#[should_panic(expected: 'Receipt ID cannot be zero')]
fn test_get_receipt_details_with_zero_id() {
    // 1. 部署合约
    let declared_contract_wrapper = ResultTrait::expect(declare("ReceiptContract"), 'Declare failed');
    let contract_to_deploy = declared_contract_wrapper.contract_class();
    let mut constructor_calldata = ArrayTrait::new();
    let (contract_address, _): (starknet::ContractAddress, core::array::Span<felt252>) =
        contract_to_deploy.deploy(@constructor_calldata).unwrap_syscall();
    
    let dispatcher = IReceiptDispatcher { contract_address };

    // 2. 尝试获取ID为0的收据，应当引发错误
    dispatcher.get_receipt_details(0_u256);
}

#[test]
#[should_panic(expected: 'Receipt not found')]
fn test_get_receipt_details_nonexistent() {
    // 1. 部署合约
    let declared_contract_wrapper = ResultTrait::expect(declare("ReceiptContract"), 'Declare failed');
    let contract_to_deploy = declared_contract_wrapper.contract_class();
    let mut constructor_calldata = ArrayTrait::new();
    let (contract_address, _): (starknet::ContractAddress, core::array::Span<felt252>) =
        contract_to_deploy.deploy(@constructor_calldata).unwrap_syscall();
    
    let dispatcher = IReceiptDispatcher { contract_address };

    // 2. 尝试获取不存在的收据ID，应当引发错误
    dispatcher.get_receipt_details(999_u256);
}

#[test]
fn test_verify_metadata() {
    // 1. 部署合约
    let declared_contract_wrapper = ResultTrait::expect(declare("ReceiptContract"), 'Declare failed');
    let contract_to_deploy = declared_contract_wrapper.contract_class();
    let mut constructor_calldata = ArrayTrait::new();
    let (contract_address, _): (starknet::ContractAddress, core::array::Span<felt252>) =
        contract_to_deploy.deploy(@constructor_calldata).unwrap_syscall();
    
    let dispatcher = IReceiptDispatcher { contract_address };

    // 2. 创建收据
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

    // 创建收据并获取ID
    let receipt_id = dispatcher.create_receipt(
        workflow_id,
        dependency_url,
        metadata,
        metadata_hash,
        metadata_uri
    );

    // 3. 验证用同一个哈希值 - 应该返回true
    let is_valid = dispatcher.verify_metadata(receipt_id, metadata_hash);
    assert(is_valid == true, 'Metadata should be valid');

    // 4. 验证用不同的哈希值 - 应该返回false
    let wrong_hash = 0x9876_felt252;
    let is_invalid = dispatcher.verify_metadata(receipt_id, wrong_hash);
    assert(is_invalid == false, 'Should detect invalid hash');
}

#[test]
#[should_panic(expected: 'Receipt ID cannot be zero')]
fn test_verify_metadata_with_zero_id() {
    // 1. 部署合约
    let declared_contract_wrapper = ResultTrait::expect(declare("ReceiptContract"), 'Declare failed');
    let contract_to_deploy = declared_contract_wrapper.contract_class();
    let mut constructor_calldata = ArrayTrait::new();
    let (contract_address, _): (starknet::ContractAddress, core::array::Span<felt252>) =
        contract_to_deploy.deploy(@constructor_calldata).unwrap_syscall();
    
    let dispatcher = IReceiptDispatcher { contract_address };

    // 2. 尝试验证ID为0的收据，应当引发错误
    dispatcher.verify_metadata(0_u256, 0x1234_felt252);
}

#[test]
#[should_panic(expected: 'Provided hash cannot be empty')]
fn test_verify_metadata_with_empty_hash() {
    // 1. 部署合约
    let declared_contract_wrapper = ResultTrait::expect(declare("ReceiptContract"), 'Declare failed');
    let contract_to_deploy = declared_contract_wrapper.contract_class();
    let mut constructor_calldata = ArrayTrait::new();
    let (contract_address, _): (starknet::ContractAddress, core::array::Span<felt252>) =
        contract_to_deploy.deploy(@constructor_calldata).unwrap_syscall();
    
    let dispatcher = IReceiptDispatcher { contract_address };

    // 2. 先创建一个收据
    let receipt_id = dispatcher.create_receipt(
        1_u256,
        'https://github.com/test/repo',
        ReceiptMetadata { name: 'test', version: '1.0', author: 'author', license: 'MIT' },
        0x1234_felt252,
        'ipfs://test'
    );

    // 3. 尝试用空哈希验证，应当引发错误
    dispatcher.verify_metadata(receipt_id, 0);
}

#[test]
fn test_update_tx_hash() {
    // 1. 部署合约
    let declared_contract_wrapper = ResultTrait::expect(declare("ReceiptContract"), 'Declare failed');
    let contract_to_deploy = declared_contract_wrapper.contract_class();
    let mut constructor_calldata = ArrayTrait::new();
    let (contract_address, _): (starknet::ContractAddress, core::array::Span<felt252>) =
        contract_to_deploy.deploy(@constructor_calldata).unwrap_syscall();
    
    let dispatcher = IReceiptDispatcher { contract_address };

    // 2. 创建收据
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

    // 创建收据并获取ID
    let receipt_id = dispatcher.create_receipt(
        workflow_id,
        dependency_url,
        metadata,
        metadata_hash,
        metadata_uri
    );

    // 3. 检查收据成功创建
    // 获取当前收据信息以确认收据确实存在
    let (_details, _) = dispatcher.get_receipt_details(receipt_id);

    // 4. 更新交易哈希
    let new_tx_hash = 0xABCD_felt252; 
    dispatcher.update_tx_hash(receipt_id, new_tx_hash);

    // 5. 再次检查收据确认修改操作成功完成
    let (_updated_details, _) = dispatcher.get_receipt_details(receipt_id);
}

#[test]
#[should_panic(expected: 'Receipt ID cannot be zero')]
fn test_update_tx_hash_with_zero_id() {
    // 1. 部署合约
    let declared_contract_wrapper = ResultTrait::expect(declare("ReceiptContract"), 'Declare failed');
    let contract_to_deploy = declared_contract_wrapper.contract_class();
    let mut constructor_calldata = ArrayTrait::new();
    let (contract_address, _): (starknet::ContractAddress, core::array::Span<felt252>) =
        contract_to_deploy.deploy(@constructor_calldata).unwrap_syscall();
    
    let dispatcher = IReceiptDispatcher { contract_address };

    // 2. 尝试更新ID为0的收据，应当引发错误
    dispatcher.update_tx_hash(0_u256, 0xABCD_felt252);
}

#[test]
#[should_panic(expected: 'Tx hash cannot be empty')]
fn test_update_tx_hash_with_empty_hash() {
    // 1. 部署合约
    let declared_contract_wrapper = ResultTrait::expect(declare("ReceiptContract"), 'Declare failed');
    let contract_to_deploy = declared_contract_wrapper.contract_class();
    let mut constructor_calldata = ArrayTrait::new();
    let (contract_address, _): (starknet::ContractAddress, core::array::Span<felt252>) =
        contract_to_deploy.deploy(@constructor_calldata).unwrap_syscall();
    
    let dispatcher = IReceiptDispatcher { contract_address };

    // 2. 先创建一个收据
    let receipt_id = dispatcher.create_receipt(
        1_u256,
        'https://github.com/test/repo',
        ReceiptMetadata { name: 'test', version: '1.0', author: 'author', license: 'MIT' },
        0x1234_felt252,
        'ipfs://test'
    );

    // 3. 尝试更新为空哈希，应当引发错误
    dispatcher.update_tx_hash(receipt_id, 0);
}

#[test]
#[should_panic(expected: 'Receipt not found')]
fn test_update_tx_hash_nonexistent() {
    // 1. 部署合约
    let declared_contract_wrapper = ResultTrait::expect(declare("ReceiptContract"), 'Declare failed');
    let contract_to_deploy = declared_contract_wrapper.contract_class();
    let mut constructor_calldata = ArrayTrait::new();
    let (contract_address, _): (starknet::ContractAddress, core::array::Span<felt252>) =
        contract_to_deploy.deploy(@constructor_calldata).unwrap_syscall();
    
    let dispatcher = IReceiptDispatcher { contract_address };

    // 2. 尝试更新不存在的收据，应当引发错误
    dispatcher.update_tx_hash(999_u256, 0xABCD_felt252);
}
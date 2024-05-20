use core::debug::PrintTrait;
use core::integer::BoundedInt;
use core::serde::Serde;
use core::starknet::storage::StorageMapMemberAccessTrait;
use core::starknet::storage::StorageMemberAccessTrait;
use openzeppelin::access::accesscontrol::accesscontrol::AccessControlComponent::InternalTrait as AccessComponentInternalTrait;
use openzeppelin::access::accesscontrol::interface::{
    AccessControlABIDispatcher, AccessControlABIDispatcherTrait
};
use openzeppelin::account::interface::{AccountABIDispatcher, AccountABIDispatcherTrait};
use openzeppelin::token::erc20::interface::{IERC20DispatcherTrait, IERC20Dispatcher};
use openzeppelin::token::erc721::erc721::ERC721Component::InternalTrait as ERC721InternalTrait;
use openzeppelin::token::erc721::interface::{
    ERC721ABI, ERC721ABIDispatcher, ERC721ABIDispatcherTrait
};
use openzeppelin::upgrades::interface::{IUpgradeableDispatcher, IUpgradeableDispatcherTrait};
use snforge_std::{
    declare, ContractClassTrait, spy_events, SpyOn, EventSpy, EventAssertions, test_address,
    start_roll, stop_roll, start_warp, stop_warp, CheatTarget, start_prank, stop_prank,
    get_class_hash
};
use starknet::ContractAddress;
use starknet::contract_address_const;
use starknet::syscalls::call_contract_syscall;
use strealm::components::strealm::IStRealm;
use strealm::components::strealm::StRealmComponent::InternalTrait as StRealmInternalTrait;
use strealm::components::strealm::StRealmComponent::{Flow, Stream};
use strealm::components::strealm::StRealmComponent;
use strealm::components::strealm::{IStRealmDispatcher, IStRealmDispatcherTrait};
use strealm::lordship::Lordship;
use strealm::lordship::{IERC721MinterDispatcher, IERC721MinterDispatcherTrait};
use strealm::tests::mocks::account_mock::DualCaseAccountMock;
use strealm::tests::mocks::erc20_mock::DualCaseERC20Mock;


/// 
/// Constants
///
///  
fn FLOW_RATE() -> u256 {
    123
}

fn DEFAULT_ADMIN() -> ContractAddress {
    contract_address_const::<'DEFAULT_ADMIN_ADDRESS'>()
}

fn MINTER() -> ContractAddress {
    contract_address_const::<'MINTER_ADDRESS'>()
}

fn UPGRADER() -> ContractAddress {
    contract_address_const::<'UPGRADER_ADDRESS'>()
}

fn REWARD_TOKEN() -> ContractAddress {
    contract_address_const::<'REWARD_TOKEN_ADDRESS'>()
}

fn REWARD_PAYER() -> ContractAddress {
    contract_address_const::<'REWARD_PAYER_ADDRESS'>()
}


fn ACCOUNT_MOCK_ADDRESS() -> ContractAddress {
    let account_contract = declare("DualCaseAccountMock").unwrap();

    let mut constructor_calldata = array![];
    let public_key: felt252 = 123;
    public_key.serialize(ref constructor_calldata);

    let (contract_address, _) = account_contract.deploy(@constructor_calldata).unwrap();

    contract_address
}


fn ERC20_MOCK() -> IERC20Dispatcher {
    let erc20_contract = declare("DualCaseERC20Mock").unwrap();

    let mut constructor_calldata = array![];
    let name: ByteArray = "MockToken";
    let symbol: ByteArray = "MToken";
    let supply: u256 = 2000000000000000000000000;
    let recipient: ContractAddress = REWARD_PAYER();
    name.serialize(ref constructor_calldata);
    symbol.serialize(ref constructor_calldata);
    supply.serialize(ref constructor_calldata);
    recipient.serialize(ref constructor_calldata);

    let (contract_address, _) = erc20_contract.deploy(@constructor_calldata).unwrap();

    let dispatcher = IERC20Dispatcher { contract_address };
    return dispatcher;
}


fn DEPLOY_LORDSHIP_CONTRACT() -> ContractAddress {
    let lordship_contract = declare("Lordship").unwrap();

    let mut constructor_calldata = array![];
    DEFAULT_ADMIN().serialize(ref constructor_calldata);
    MINTER().serialize(ref constructor_calldata);
    UPGRADER().serialize(ref constructor_calldata);
    FLOW_RATE().serialize(ref constructor_calldata);
    REWARD_TOKEN().serialize(ref constructor_calldata);
    REWARD_PAYER().serialize(ref constructor_calldata);

    let (contract_address, _) = lordship_contract.deploy(@constructor_calldata).unwrap();

    contract_address
}


/// 
/// Tests
///

#[test]
fn test_constructor() {
    let mut lordship_address = DEPLOY_LORDSHIP_CONTRACT();

    // ensure roles are correct
    let access_control_dispatcher = AccessControlABIDispatcher {
        contract_address: lordship_address
    };
    assert!(access_control_dispatcher.has_role(Lordship::DEFAULT_ADMIN_ROLE, DEFAULT_ADMIN()));
    assert!(access_control_dispatcher.has_role(Lordship::MINTER_ROLE, MINTER()));
    assert!(access_control_dispatcher.has_role(Lordship::UPGRADER_ROLE, UPGRADER()));

    // ensure erc721 was initialized properly
    let erc721_dispatcher = ERC721ABIDispatcher { contract_address: lordship_address };
    assert_eq!(erc721_dispatcher.name(), "Staked Realm");
    assert_eq!(erc721_dispatcher.symbol(), "stREALM");

    // ensure strealm component was initialized properly
    let strealm_dispatcher = IStRealmDispatcher { contract_address: lordship_address };
    assert_eq!(strealm_dispatcher.get_latest_flow_id(), 1);
    assert_eq!(strealm_dispatcher.get_flow(1).rate, FLOW_RATE());
    assert_eq!(strealm_dispatcher.get_flow(1).end_at, BoundedInt::max());
    assert_eq!(strealm_dispatcher.get_reward_payer(), REWARD_PAYER());
    assert_eq!(strealm_dispatcher.get_reward_token(), REWARD_TOKEN());
}


#[test]
fn test_upgrade() {
    let mut lordship_address = DEPLOY_LORDSHIP_CONTRACT();

    // change class hash to erc20 class hash
    start_prank(CheatTarget::One(lordship_address), UPGRADER());
    let new_class_hash = get_class_hash(ERC20_MOCK().contract_address);
    IUpgradeableDispatcher { contract_address: lordship_address }.upgrade(new_class_hash);
    stop_prank(CheatTarget::One(lordship_address));

    let erc20_dispatcher = IERC20Dispatcher { contract_address: lordship_address };
    assert_eq!(erc20_dispatcher.total_supply(), 0);
}


#[test]
#[should_panic(expected: ('Caller is missing role',))]
fn test_upgrade_no_permission() {
    let mut lordship_address = DEPLOY_LORDSHIP_CONTRACT();

    // change class hash to erc20 class hash
    // start_prank(CheatTarget::One(lordship_address), UPGRADER());
    let new_class_hash = get_class_hash(ERC20_MOCK().contract_address);
    IUpgradeableDispatcher { contract_address: lordship_address }.upgrade(new_class_hash);
// stop_prank(CheatTarget::One(lordship_address));
}


#[test]
fn test_safe_mint() {
    let mut lordship_address = DEPLOY_LORDSHIP_CONTRACT();

    start_prank(CheatTarget::One(lordship_address), MINTER());

    let erc721_minter_dispatcher = IERC721MinterDispatcher { contract_address: lordship_address };
    let mint_token_id = 44_u256;
    let mint_recipient = ACCOUNT_MOCK_ADDRESS();
    let mint_data: Span<felt252> = array![].span();
    erc721_minter_dispatcher.safe_mint(mint_recipient, mint_token_id, mint_data);
    stop_prank(CheatTarget::One(lordship_address));

    let erc721_dispatcher = ERC721ABIDispatcher { contract_address: lordship_address };
    assert_eq!(erc721_dispatcher.balance_of(mint_recipient), 1);
    assert_eq!(erc721_dispatcher.owner_of(mint_token_id), mint_recipient);
}


#[test]
#[should_panic(expected: ('Caller is missing role',))]
fn test_safe_mint_no_permission() {
    let mut lordship_address = DEPLOY_LORDSHIP_CONTRACT();

    // start_prank(CheatTarget::One(lordship_address), MINTER());

    let erc721_minter_dispatcher = IERC721MinterDispatcher { contract_address: lordship_address };
    let mint_token_id = 44_u256;
    let mint_recipient = ACCOUNT_MOCK_ADDRESS();
    let mint_data: Span<felt252> = array![].span();
    erc721_minter_dispatcher.safe_mint(mint_recipient, mint_token_id, mint_data);
// stop_prank(CheatTarget::One(lordship_address));

}


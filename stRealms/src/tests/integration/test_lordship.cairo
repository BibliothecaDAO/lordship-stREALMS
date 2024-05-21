use core::debug::PrintTrait;
use core::integer::BoundedInt;
use core::option::OptionTrait;
use core::serde::Serde;
use core::starknet::storage::StorageMapMemberAccessTrait;
use core::starknet::storage::StorageMemberAccessTrait;
use core::traits::TryInto;
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
use strealm::components::erc721::extensions::erc721_votes::{
    IERC721VotesDispatcher, IERC721VotesDispatcherTrait
};
use strealm::components::strealm::IStRealm;
use strealm::components::strealm::StRealmComponent::InternalTrait as StRealmInternalTrait;
use strealm::components::strealm::StRealmComponent::{Flow, Stream};
use strealm::components::strealm::StRealmComponent;
use strealm::components::strealm::{IStRealmDispatcher, IStRealmDispatcherTrait};
use strealm::lordship::Lordship;
use strealm::lordship::{IERC721MinterBurnerDispatcher, IERC721MinterBurnerDispatcherTrait};
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


fn ACCOUNT_MOCK_ADDRESSES() -> (ContractAddress, ContractAddress) {
    let account_contract = declare("DualCaseAccountMock").unwrap();

    let mut constructor_calldata = array![];
    let public_key: felt252 = 123;
    public_key.serialize(ref constructor_calldata);

    let (contract_address_one, _) = account_contract.deploy(@constructor_calldata).unwrap();
    let (contract_address_two, _) = account_contract.deploy(@constructor_calldata).unwrap();

    (contract_address_one, contract_address_two)
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

    let erc721_minter_dispatcher = IERC721MinterBurnerDispatcher {
        contract_address: lordship_address
    };
    let mint_token_id = 44_u256;
    let (mint_recipient, _) = ACCOUNT_MOCK_ADDRESSES();
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

    let erc721_minter_dispatcher = IERC721MinterBurnerDispatcher {
        contract_address: lordship_address
    };
    let mint_token_id = 44_u256;
    let (mint_recipient, _) = ACCOUNT_MOCK_ADDRESSES();
    let mint_data: Span<felt252> = array![].span();
    erc721_minter_dispatcher.safe_mint(mint_recipient, mint_token_id, mint_data);
// stop_prank(CheatTarget::One(lordship_address));

}


#[test]
fn test_burn() {
    let mut lordship_address = DEPLOY_LORDSHIP_CONTRACT();

    start_prank(CheatTarget::One(lordship_address), MINTER());

    let erc721_minter_dispatcher = IERC721MinterBurnerDispatcher {
        contract_address: lordship_address
    };
    let mint_token_id = 44_u256;
    let (mint_recipient, _) = ACCOUNT_MOCK_ADDRESSES();
    let mint_data: Span<felt252> = array![].span();
    erc721_minter_dispatcher.safe_mint(mint_recipient, mint_token_id, mint_data);
    stop_prank(CheatTarget::One(lordship_address));

    start_prank(CheatTarget::One(lordship_address), MINTER());
    erc721_minter_dispatcher.burn(mint_token_id);
    stop_prank(CheatTarget::One(lordship_address));

    let erc721_dispatcher = ERC721ABIDispatcher { contract_address: lordship_address };
    assert_eq!(erc721_dispatcher.balance_of(mint_recipient), 0);
}


#[test]
#[should_panic(expected: ('Caller is missing role',))]
fn test_burn_no_permission() {
    let mut lordship_address = DEPLOY_LORDSHIP_CONTRACT();

    start_prank(CheatTarget::One(lordship_address), MINTER());

    let erc721_minter_dispatcher = IERC721MinterBurnerDispatcher {
        contract_address: lordship_address
    };
    let mint_token_id = 44_u256;
    let (mint_recipient, _) = ACCOUNT_MOCK_ADDRESSES();
    let mint_data: Span<felt252> = array![].span();
    erc721_minter_dispatcher.safe_mint(mint_recipient, mint_token_id, mint_data);
    stop_prank(CheatTarget::One(lordship_address));

    // start_prank(CheatTarget::One(lordship_address), MINTER());
    erc721_minter_dispatcher.burn(mint_token_id);
// stop_prank(CheatTarget::One(lordship_address));
}


#[test]
fn test_delegate_hook__ensure_stream_starts_after_delegate() {
    let mut lordship_address = DEPLOY_LORDSHIP_CONTRACT();

    // set starting block timestamp to 3
    let block_timestamp = 3;
    start_warp(CheatTarget::All, block_timestamp);

    // mint 4 tokens to recipient
    let (mint_recipient, _) = ACCOUNT_MOCK_ADDRESSES();
    start_prank(CheatTarget::One(lordship_address), MINTER());

    let num_nfts = 4_u256;
    let erc721_minter_dispatcher = IERC721MinterBurnerDispatcher {
        contract_address: lordship_address
    };
    erc721_minter_dispatcher.safe_mint(mint_recipient, 1, array![].span());
    erc721_minter_dispatcher.safe_mint(mint_recipient, 2, array![].span());
    erc721_minter_dispatcher.safe_mint(mint_recipient, 3, array![].span());
    erc721_minter_dispatcher.safe_mint(mint_recipient, 4, array![].span());
    stop_prank(CheatTarget::One(lordship_address));

    // ensure mint recipient has no delegate
    start_prank(CheatTarget::One(lordship_address), mint_recipient);
    let erc721_votes_dispatcher = IERC721VotesDispatcher { contract_address: lordship_address };
    assert!(
        erc721_votes_dispatcher.delegates(mint_recipient) == Zeroable::zero(),
        "recipient should have no delegate"
    );

    // ensure that a stream does not exist
    let strealm_dispatcher = IStRealmDispatcher { contract_address: lordship_address };
    assert_eq!(strealm_dispatcher.get_stream(mint_recipient).flow_id, 0);
    assert_eq!(strealm_dispatcher.get_stream(mint_recipient).start_at, 0);

    // move 12 seconds into the future and ensure stream balance is unchanged i.e 0
    let block_timestamp = block_timestamp + 12;
    start_warp(CheatTarget::All, block_timestamp);
    let strealm_dispatcher = IStRealmDispatcher { contract_address: lordship_address };
    assert_eq!(strealm_dispatcher.get_reward_balance(), 0);

    // delegate
    let delegatee_address = contract_address_const::<'delegatee_address'>();
    erc721_votes_dispatcher.delegate(delegatee_address);

    assert!(
        erc721_votes_dispatcher.delegates(mint_recipient) == delegatee_address,
        "recipient should have a delegate"
    );
    assert!(
        erc721_votes_dispatcher.get_votes(delegatee_address) == 4,
        "delegate address should have 4 vote"
    );

    // ensure that a stream was created
    assert_eq!(strealm_dispatcher.get_stream(mint_recipient).flow_id, 1);
    assert_eq!(strealm_dispatcher.get_stream(mint_recipient).start_at, block_timestamp);

    // move 5 seconds into the future and ensure stream balance is correct
    let num_seconds_passed = 5;
    let block_timestamp = block_timestamp + num_seconds_passed;
    start_warp(CheatTarget::All, block_timestamp);
    assert_eq!(
        strealm_dispatcher.get_reward_balance(),
        num_nfts * num_seconds_passed.into() * FLOW_RATE().into()
    );
}


#[test]
fn test_delegate_hook__ensure_stream_end_after_delegate_to_0() {
    let mut lordship_address = DEPLOY_LORDSHIP_CONTRACT();

    // set starting block timestamp to 3
    let block_timestamp = 3;
    start_warp(CheatTarget::All, block_timestamp);

    // mint 4 tokens to recipient
    let (mint_recipient, _) = ACCOUNT_MOCK_ADDRESSES();
    start_prank(CheatTarget::One(lordship_address), MINTER());

    let num_nfts = 4_u256;
    let erc721_minter_dispatcher = IERC721MinterBurnerDispatcher {
        contract_address: lordship_address
    };
    erc721_minter_dispatcher.safe_mint(mint_recipient, 1, array![].span());
    erc721_minter_dispatcher.safe_mint(mint_recipient, 2, array![].span());
    erc721_minter_dispatcher.safe_mint(mint_recipient, 3, array![].span());
    erc721_minter_dispatcher.safe_mint(mint_recipient, 4, array![].span());
    stop_prank(CheatTarget::One(lordship_address));

    // ensure mint recipient has no delegates
    start_prank(CheatTarget::One(lordship_address), mint_recipient);
    let erc721_votes_dispatcher = IERC721VotesDispatcher { contract_address: lordship_address };
    assert!(
        erc721_votes_dispatcher.delegates(mint_recipient) == Zeroable::zero(),
        "recipient should have no delegate"
    );

    // ensure that a stream does not exist
    let strealm_dispatcher = IStRealmDispatcher { contract_address: lordship_address };
    assert_eq!(strealm_dispatcher.get_stream(mint_recipient).flow_id, 0);
    assert_eq!(strealm_dispatcher.get_stream(mint_recipient).start_at, 0);

    // delegate to delegatee
    let delegatee_address = contract_address_const::<'delegatee_address'>();
    erc721_votes_dispatcher.delegate(delegatee_address);

    assert!(
        erc721_votes_dispatcher.delegates(mint_recipient) == delegatee_address,
        "recipient should have a delegate"
    );
    assert!(
        erc721_votes_dispatcher.get_votes(delegatee_address) == 4,
        "delegate address should have one vote"
    );

    // ensure that a stream was created
    assert_eq!(strealm_dispatcher.get_stream(mint_recipient).flow_id, 1);
    assert_eq!(strealm_dispatcher.get_stream(mint_recipient).start_at, block_timestamp);

    // move 5 seconds into the future 
    let first_num_seconds_passed = 5;
    let block_timestamp = block_timestamp + first_num_seconds_passed;
    start_warp(CheatTarget::All, block_timestamp);

    // ensure stream balance is correct
    let strealm_dispatcher = IStRealmDispatcher { contract_address: lordship_address };
    assert_eq!(
        strealm_dispatcher.get_reward_balance(),
        num_nfts * first_num_seconds_passed.into() * FLOW_RATE().into()
    );

    // delegate to zero address
    erc721_votes_dispatcher.delegate(Zeroable::zero());

    // move another 10 seconds into the future 
    let second_num_seconds_passed = 10;
    let block_timestamp = block_timestamp + second_num_seconds_passed;
    start_warp(CheatTarget::All, block_timestamp);

    // ensure stream balance is unchanged
    assert_eq!(
        strealm_dispatcher.get_reward_balance(),
        num_nfts * first_num_seconds_passed.into() * FLOW_RATE().into()
    );

    // ensure that a stream was deleted
    assert_eq!(strealm_dispatcher.get_stream(mint_recipient).flow_id, 0);
    assert_eq!(strealm_dispatcher.get_stream(mint_recipient).start_at, 0);
}


#[test]
fn test_delegate_hook__ensure_nothing_happens_if_you_change_existing_delegate() {
    let mut lordship_address = DEPLOY_LORDSHIP_CONTRACT();

    // set starting block timestamp to 3
    let block_timestamp = 3;
    start_warp(CheatTarget::All, block_timestamp);

    // mint 4 tokens to recipient
    let (mint_recipient, _) = ACCOUNT_MOCK_ADDRESSES();
    start_prank(CheatTarget::One(lordship_address), MINTER());

    let num_nfts = 4_u256;
    let erc721_minter_dispatcher = IERC721MinterBurnerDispatcher {
        contract_address: lordship_address
    };
    erc721_minter_dispatcher.safe_mint(mint_recipient, 1, array![].span());
    erc721_minter_dispatcher.safe_mint(mint_recipient, 2, array![].span());
    erc721_minter_dispatcher.safe_mint(mint_recipient, 3, array![].span());
    erc721_minter_dispatcher.safe_mint(mint_recipient, 4, array![].span());
    stop_prank(CheatTarget::One(lordship_address));

    // ensure mint recipient has no delegates
    start_prank(CheatTarget::One(lordship_address), mint_recipient);
    let erc721_votes_dispatcher = IERC721VotesDispatcher { contract_address: lordship_address };
    assert!(
        erc721_votes_dispatcher.delegates(mint_recipient) == Zeroable::zero(),
        "recipient should have no delegate"
    );

    // ensure that a stream does not exist
    let strealm_dispatcher = IStRealmDispatcher { contract_address: lordship_address };
    assert_eq!(strealm_dispatcher.get_stream(mint_recipient).flow_id, 0);
    assert_eq!(strealm_dispatcher.get_stream(mint_recipient).start_at, 0);

    // delegate to delegatee
    let delegatee_address = contract_address_const::<'delegatee_address'>();
    let delegatee_address_two = contract_address_const::<'delegatee_address_two'>();
    erc721_votes_dispatcher.delegate(delegatee_address);

    assert!(
        erc721_votes_dispatcher.delegates(mint_recipient) == delegatee_address,
        "recipient should have a delegate"
    );
    assert!(
        erc721_votes_dispatcher.get_votes(delegatee_address) == 4,
        "delegate address should have one vote"
    );

    // ensure that a stream was created
    assert_eq!(strealm_dispatcher.get_stream(mint_recipient).flow_id, 1);
    assert_eq!(strealm_dispatcher.get_stream(mint_recipient).start_at, block_timestamp);

    // move 5 seconds into the future 
    let first_num_seconds_passed = 5;
    let block_timestamp = block_timestamp + first_num_seconds_passed;
    start_warp(CheatTarget::All, block_timestamp);

    // ensure stream balance is correct
    let strealm_dispatcher = IStRealmDispatcher { contract_address: lordship_address };
    assert_eq!(
        strealm_dispatcher.get_reward_balance(),
        num_nfts * first_num_seconds_passed.into() * FLOW_RATE().into()
    );

    // delegate to another address
    erc721_votes_dispatcher.delegate(delegatee_address_two);

    // move another 10 seconds into the future 
    let second_num_seconds_passed = 10;
    let block_timestamp = block_timestamp + second_num_seconds_passed;
    start_warp(CheatTarget::All, block_timestamp);

    // ensure stream balance is accurate
    assert_eq!(
        strealm_dispatcher.get_reward_balance(),
        num_nfts
            * (first_num_seconds_passed + second_num_seconds_passed).into()
            * FLOW_RATE().into()
    );

    // ensure that a stream is still active and accurate
    assert_eq!(strealm_dispatcher.get_stream(mint_recipient).flow_id, 1);
    assert_eq!(strealm_dispatcher.get_stream(mint_recipient).start_at, 3);
}


#[test]
fn test_update_hook() {
    ///  Ensure transfer updates stream balance for person_A and recipient

    let mut lordship_address = DEPLOY_LORDSHIP_CONTRACT();

    // set starting block timestamp to 3
    let block_timestamp = 3;
    start_warp(CheatTarget::All, block_timestamp);

    start_prank(CheatTarget::One(lordship_address), MINTER());

    let erc721_minter_dispatcher = IERC721MinterBurnerDispatcher {
        contract_address: lordship_address
    };

    let (person_A, person_B) = ACCOUNT_MOCK_ADDRESSES();

    // mint 2 tokens to person_A
    erc721_minter_dispatcher.safe_mint(person_A, 1, array![].span());
    erc721_minter_dispatcher.safe_mint(person_A, 2, array![].span());

    // mint 3 tokens to person_B
    erc721_minter_dispatcher.safe_mint(person_B, 3, array![].span());
    erc721_minter_dispatcher.safe_mint(person_B, 4, array![].span());
    erc721_minter_dispatcher.safe_mint(person_B, 5, array![].span());

    stop_prank(CheatTarget::One(lordship_address));

    // person_A and person B delegate
    let delegatee_address_one = contract_address_const::<'delegatee_address_one'>();
    let erc721_votes_dispatcher = IERC721VotesDispatcher { contract_address: lordship_address };

    start_prank(CheatTarget::One(lordship_address), person_A);
    erc721_votes_dispatcher.delegate(delegatee_address_one);

    start_prank(CheatTarget::One(lordship_address), person_B);
    erc721_votes_dispatcher.delegate(delegatee_address_one);

    // ensure that a stream was created for person_A
    let strealm_dispatcher = IStRealmDispatcher { contract_address: lordship_address };
    assert_eq!(strealm_dispatcher.get_stream(person_A).flow_id, 1);
    assert_eq!(strealm_dispatcher.get_stream(person_A).start_at, block_timestamp);

    // move 5 seconds into the future 
    let first_num_seconds_passed = 5;
    let block_timestamp = block_timestamp + first_num_seconds_passed;
    start_warp(CheatTarget::All, block_timestamp);

    // ensure person_A stream balance is correct
    start_prank(CheatTarget::One(lordship_address), person_A);
    let expected_person_A_balance = 2 * first_num_seconds_passed.into() * FLOW_RATE().into();
    assert_eq!(strealm_dispatcher.get_reward_balance(), expected_person_A_balance);

    // ensure person_B stream balance is correct
    start_prank(CheatTarget::One(lordship_address), person_B);
    let expected_person_B_balance = 3 * first_num_seconds_passed.into() * FLOW_RATE().into();
    assert_eq!(strealm_dispatcher.get_reward_balance(), expected_person_B_balance);

    // Person A sends 1 stRealm to person B
    let erc721_dispatcher = ERC721ABIDispatcher { contract_address: lordship_address };
    start_prank(CheatTarget::One(lordship_address), person_A);
    erc721_dispatcher.transfer_from(person_A, person_B, 1);

    // ensure person A stream has been reset
    assert_eq!(strealm_dispatcher.get_stream(person_A).flow_id, 1);
    assert_eq!(strealm_dispatcher.get_stream(person_A).start_at, block_timestamp);

    // ensure person B stream has been reset
    assert_eq!(strealm_dispatcher.get_stream(person_B).flow_id, 1);
    assert_eq!(strealm_dispatcher.get_stream(person_B).start_at, block_timestamp);

    // ensure person_A stream balance is the same
    start_prank(CheatTarget::One(lordship_address), person_A);
    assert_eq!(strealm_dispatcher.get_reward_balance(), expected_person_A_balance);

    // ensure person_B stream balance is the same
    start_prank(CheatTarget::One(lordship_address), person_B);
    assert_eq!(strealm_dispatcher.get_reward_balance(), expected_person_B_balance);

    // move another 10 seconds into the future 
    let second_num_seconds_passed = 10;
    let block_timestamp = block_timestamp + second_num_seconds_passed;
    start_warp(CheatTarget::All, block_timestamp);

    // ensure new person_A stream balance is cirrect
    start_prank(CheatTarget::One(lordship_address), person_A);
    let new_expected_person_A_balance = expected_person_A_balance
        + ((2 - 1) * second_num_seconds_passed.into() * FLOW_RATE().into());
    assert_eq!(strealm_dispatcher.get_reward_balance(), new_expected_person_A_balance);

    // ensure new person_B stream balance is cirrect
    start_prank(CheatTarget::One(lordship_address), person_B);
    let new_expected_person_B_balance = expected_person_B_balance
        + ((3 + 1) * second_num_seconds_passed.into() * FLOW_RATE().into());
    assert_eq!(strealm_dispatcher.get_reward_balance(), new_expected_person_B_balance);
}

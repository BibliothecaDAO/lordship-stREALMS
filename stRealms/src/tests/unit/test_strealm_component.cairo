use core::debug::PrintTrait;
use core::integer::BoundedInt;
use core::serde::Serde;
use core::starknet::storage::StorageMapMemberAccessTrait;
use core::starknet::storage::StorageMemberAccessTrait;
use openzeppelin::access::accesscontrol::accesscontrol::AccessControlComponent::InternalTrait as AccessComponentInternalTrait;
use openzeppelin::token::erc20::interface::{IERC20DispatcherTrait, IERC20Dispatcher};
use openzeppelin::token::erc721::erc721::ERC721Component::InternalTrait as ERC721InternalTrait;
use snforge_std::{
    declare, ContractClassTrait, spy_events, SpyOn, EventSpy, EventAssertions, test_address,
    start_roll, stop_roll, start_warp, stop_warp, CheatTarget, start_prank, stop_prank
};
use starknet::ContractAddress;
use starknet::contract_address_const;
use strealm::components::strealm::IStRealm;
use strealm::components::strealm::StRealmComponent::InternalTrait as StRealmInternalTrait;
use strealm::components::strealm::StRealmComponent::{Flow, Stream};
use strealm::components::strealm::StRealmComponent;
use strealm::components::strealm::{IStRealmDispatcher, IStRealmDispatcherTrait};
use strealm::tests::mocks::erc20_mock::DualCaseERC20Mock;

use strealm::tests::mocks::strealm_mock::StRealmMock;

/// 
/// Constants
///
///  
fn FLOW_RATE() -> u256 {
    123
}

fn DEFAULT_ADMIN() -> ContractAddress {
    contract_address_const::<'DEFAULT_ADMIN'>()
}

fn REWARD_TOKEN() -> ContractAddress {
    contract_address_const::<'REWARD_TOKEN'>()
}

fn REWARD_PAYER() -> ContractAddress {
    contract_address_const::<'REWARD_PAYER'>()
}

type ContractState = StRealmMock::ContractState;


fn ERC20_MOCK() -> IERC20Dispatcher {
    // First declare and deploy a contract
    let erc20_contract = declare("DualCaseERC20Mock").unwrap();
    // Alternatively we could use `deploy_syscall` here
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


fn STREALM_CONTRACT_STATE() -> ContractState {
    let mut cs = StRealmMock::contract_state_for_testing();
    cs.strealm.initializer(FLOW_RATE(), REWARD_TOKEN(), REWARD_PAYER());
    cs
}

/// 
/// Tests
///

/// 
/// 
/// Internal/ Private  functions Tests
/// 
/// 

#[test]
fn test_initializer() {
    let mut strealm_mock_cs = STREALM_CONTRACT_STATE();

    let latest_flow_id: u64 = strealm_mock_cs.strealm.get_latest_flow_id();
    assert_eq!(latest_flow_id, 1);

    let latest_flow: Flow = strealm_mock_cs.strealm.get_flow(latest_flow_id);
    assert_eq!(latest_flow.rate, FLOW_RATE());
    assert_eq!(latest_flow.end_at, BoundedInt::max());

    let reward_token: ContractAddress = strealm_mock_cs.strealm.get_reward_token();
    assert_eq!(reward_token, REWARD_TOKEN());

    let reward_payer: ContractAddress = strealm_mock_cs.strealm.get_reward_payer();
    assert_eq!(reward_payer, REWARD_PAYER());
}


#[test]
fn test_internal_update_flow_rate() {
    let mut strealm_mock_cs = STREALM_CONTRACT_STATE();

    let old_flow_id: u64 = strealm_mock_cs.strealm.get_latest_flow_id();

    // update flow rate 
    let new_flow_rate = 777;
    strealm_mock_cs.strealm._update_flow_rate(new_flow_rate);

    // check that the old flow rate has ended
    let old_flow: Flow = strealm_mock_cs.strealm.get_flow(old_flow_id);
    assert_eq!(old_flow_id, 1);
    assert_eq!(old_flow.rate, FLOW_RATE());
    assert_eq!(old_flow.end_at, 0);

    // check that new flow rate has been added
    let latest_flow_id: u64 = strealm_mock_cs.strealm.get_latest_flow_id();
    assert_eq!(latest_flow_id, 2);

    let latest_flow: Flow = strealm_mock_cs.strealm.get_flow(latest_flow_id);
    assert_eq!(latest_flow.rate, new_flow_rate);
    assert_eq!(latest_flow.end_at, BoundedInt::max());
}


#[test]
fn test_internal_update_reward_token() {
    let mut strealm_mock_cs = STREALM_CONTRACT_STATE();

    let new_reward_token_address = contract_address_const::<'new_reward_token_address'>();
    strealm_mock_cs.strealm._update_reward_token(new_reward_token_address);
    assert_eq!(strealm_mock_cs.strealm.get_reward_token(), new_reward_token_address);
}


#[test]
fn test_internal_update_reward_payer() {
    let mut strealm_mock_cs = STREALM_CONTRACT_STATE();

    let new_reward_payer_address = contract_address_const::<'new_reward_payer_address'>();
    strealm_mock_cs.strealm._update_reward_payer(new_reward_payer_address);
    assert_eq!(strealm_mock_cs.strealm.get_reward_payer(), new_reward_payer_address);
}


#[test]
fn test_internal_end_latest_flow() {
    let mut strealm_mock_cs = STREALM_CONTRACT_STATE();
    // ensure that latest flow id is 1
    assert_eq!(strealm_mock_cs.strealm.get_latest_flow_id(), 1);
    let latest_flow: Flow = strealm_mock_cs
        .strealm
        .get_flow(strealm_mock_cs.strealm.get_latest_flow_id());
    assert_eq!(latest_flow.rate, FLOW_RATE());
    assert_eq!(latest_flow.end_at, BoundedInt::max());

    // end latest flow
    strealm_mock_cs.strealm._end_latest_flow();

    // ensure new flow values are correct
    let latest_flow: Flow = strealm_mock_cs
        .strealm
        .get_flow(strealm_mock_cs.strealm.get_latest_flow_id());
    assert_eq!(latest_flow.rate, FLOW_RATE());
    assert_eq!(latest_flow.end_at, 0);
}


#[test]
fn test_internal_start_new_flow() {
    let mut strealm_mock_cs = STREALM_CONTRACT_STATE();
    // ensure that latest flow id is 1
    assert_eq!(strealm_mock_cs.strealm.get_latest_flow_id(), 1);
    let latest_flow: Flow = strealm_mock_cs
        .strealm
        .get_flow(strealm_mock_cs.strealm.get_latest_flow_id());
    assert_eq!(latest_flow.rate, FLOW_RATE());
    assert_eq!(latest_flow.end_at, BoundedInt::max());

    // end latest flow
    let new_rate = 999;
    strealm_mock_cs.strealm._start_new_flow(new_rate);

    // ensure new flow values are correct
    let latest_flow: Flow = strealm_mock_cs
        .strealm
        .get_flow(strealm_mock_cs.strealm.get_latest_flow_id());
    assert_eq!(latest_flow.rate, new_rate);
    assert_eq!(latest_flow.end_at, BoundedInt::max());
}

#[test]
fn test_internal_restart_stream() {
    let mut strealm_mock_cs = STREALM_CONTRACT_STATE();
    // setup
    let owner: ContractAddress = contract_address_const::<'ownerx'>();
    strealm_mock_cs.strealm.StRealm_streams.write(owner, Stream { start_at: 14, flow_id: 14 });

    // reset stream
    let block_timestamp = 400;
    start_warp(CheatTarget::One(test_address()), block_timestamp);
    strealm_mock_cs.strealm._restart_stream(owner);

    // ensure new stream values are correct
    let stream = strealm_mock_cs.strealm.get_stream(owner);
    assert_eq!(stream.start_at, block_timestamp);
    assert_eq!(stream.flow_id, strealm_mock_cs.strealm.get_latest_flow_id());
}


#[test]
fn test_internal_reward_balance_with_active_flow() {
    // check that the computed reward balance is correct
    let mut strealm_mock_cs = STREALM_CONTRACT_STATE();
    ///
    ///  start setup
    /// 
    let owner: ContractAddress = contract_address_const::<'ownerx'>();
    let stream: Stream = Stream {
        start_at: 1, flow_id: strealm_mock_cs.strealm.get_latest_flow_id()
    };
    strealm_mock_cs.strealm.StRealm_streams.write(owner, stream);

    // set give caller x nfts 
    let owner_nft_count = 2_u256;
    strealm_mock_cs.erc721.ERC721_balances.write(owner, owner_nft_count);

    ///
    ///  end  setup
    /// 

    // move 40 seconds into the future
    let _40_seconds_later = stream.start_at + 40_u64;
    start_warp(CheatTarget::One(test_address()), _40_seconds_later);

    // get reward balance
    let expected_balance = (_40_seconds_later.into() - stream.start_at.into())
        * owner_nft_count.into()
        * FLOW_RATE();

    // ensure actual balance is expected balance
    let (actual_balance, owner_has_stream) = strealm_mock_cs.strealm._reward_balance(owner);
    assert_eq!(actual_balance, expected_balance);
    assert_eq!(owner_has_stream, true);
}


#[test]
fn test_internal_reward_balance_with_inactive_flow() {
    // check that the computed reward balance is correct
    let mut strealm_mock_cs = STREALM_CONTRACT_STATE();

    ///
    ///  start setup
    /// 

    let owner: ContractAddress = contract_address_const::<'ownerx'>();
    let stream: Stream = Stream {
        start_at: 1, flow_id: strealm_mock_cs.strealm.get_latest_flow_id()
    };
    strealm_mock_cs.strealm.StRealm_streams.write(owner, stream);

    // set give caller x nfts 
    let owner_nft_count = 2_u256;
    strealm_mock_cs.erc721.ERC721_balances.write(owner, owner_nft_count);

    // move 10 seconds into the future
    let _10_seconds_later = stream.start_at + 10;
    start_warp(CheatTarget::One(test_address()), _10_seconds_later);

    // start new flow after 10 seconds
    let new_flow_rate = 3;
    strealm_mock_cs.strealm._update_flow_rate(new_flow_rate);

    ///
    ///  end setup
    /// 

    // move 40 seconds into the future
    let _40_seconds_later = starknet::get_block_timestamp() + 40;
    start_warp(CheatTarget::One(test_address()), _40_seconds_later);

    // get reward balance which should have stopped the moment a new flow was made
    let expected_balance = (_10_seconds_later.into() - stream.start_at.into())
        * owner_nft_count.into()
        * FLOW_RATE();

    // ensure actual balance is expected balance
    let (actual_balance, owner_has_stream) = strealm_mock_cs.strealm._reward_balance(owner);
    assert_eq!(actual_balance, expected_balance);
    assert_eq!(owner_has_stream, true);
}


#[test]
fn test_internal_reward_balance_with_no_active_stream() {
    // check that the computed reward balance is correct
    let mut strealm_mock_cs = STREALM_CONTRACT_STATE();

    ///
    ///  start setup
    /// 

    let owner: ContractAddress = contract_address_const::<'ownerx'>();

    // set existing balance
    let existing_balance = 11;
    strealm_mock_cs.strealm.StRealm_staker_reward_balance.write(owner, existing_balance);

    // set give caller x nfts 
    let owner_nft_count = 2_u256;
    strealm_mock_cs.erc721.ERC721_balances.write(owner, owner_nft_count);

    // move 10 seconds into the future
    let _10_seconds_later = 10;
    start_warp(CheatTarget::One(test_address()), _10_seconds_later);

    ///
    ///  end setup
    /// 

    // ensure actual balance is expected balance
    let (actual_balance, owner_has_stream) = strealm_mock_cs.strealm._reward_balance(owner);
    assert_eq!(actual_balance, existing_balance);
    assert_eq!(owner_has_stream, false);
}


#[test]
fn test_internal_update_stream_balance() {
    // check that the saved reward balance is correct

    let mut strealm_mock_cs = STREALM_CONTRACT_STATE();
    ///
    ///  start setup
    /// 
    let owner: ContractAddress = contract_address_const::<'ownerx'>();
    let stream: Stream = Stream {
        start_at: 1, flow_id: strealm_mock_cs.strealm.get_latest_flow_id()
    };
    strealm_mock_cs.strealm.StRealm_streams.write(owner, stream);

    // set give caller x nfts 
    let owner_nft_count = 2_u256;
    strealm_mock_cs.erc721.ERC721_balances.write(owner, owner_nft_count);

    ///
    ///  end  setup
    /// 

    // move 40 seconds into the future
    let _40_seconds_later = stream.start_at + 40_u64;
    start_warp(CheatTarget::One(test_address()), _40_seconds_later);
    // update stream balance
    strealm_mock_cs.strealm._update_stream_balance(owner);
    let expected_balance = (_40_seconds_later.into() - stream.start_at.into())
        * owner_nft_count.into()
        * FLOW_RATE();

    // ensure saved balance is expected balance
    assert_eq!(strealm_mock_cs.strealm.StRealm_staker_reward_balance.read(owner), expected_balance);

    // move another 40 seconds into the future  i.e at the 81st second
    let _80_seconds_later = starknet::get_block_timestamp() + 40_u64;
    start_warp(CheatTarget::One(test_address()), _80_seconds_later);
    // update stream balance again
    strealm_mock_cs.strealm._update_stream_balance(owner);
    let expected_balance = (_80_seconds_later.into() - stream.start_at.into())
        * owner_nft_count.into()
        * FLOW_RATE();
    // ensure saved balance is expected balance
    assert_eq!(strealm_mock_cs.strealm.StRealm_staker_reward_balance.read(owner), expected_balance);
}


#[test]
fn test_internal_update_stream_balance_gives_same_result_even_after_many_calls() {
    // ensure multiple calls does not add to balance

    let mut strealm_mock_cs = STREALM_CONTRACT_STATE();
    ///
    ///  start setup
    /// 
    let owner: ContractAddress = contract_address_const::<'ownerx'>();
    let stream: Stream = Stream {
        start_at: 1, flow_id: strealm_mock_cs.strealm.get_latest_flow_id()
    };
    strealm_mock_cs.strealm.StRealm_streams.write(owner, stream);

    // set give caller x nfts 
    let owner_nft_count = 2_u256;
    strealm_mock_cs.erc721.ERC721_balances.write(owner, owner_nft_count);

    ///
    ///  end  setup
    /// 

    // move 40 seconds into the future
    let _40_seconds_later = stream.start_at + 40_u64;
    start_warp(CheatTarget::One(test_address()), _40_seconds_later);
    // update stream balance many times
    strealm_mock_cs.strealm._update_stream_balance(owner);
    strealm_mock_cs.strealm._update_stream_balance(owner);
    strealm_mock_cs.strealm._update_stream_balance(owner);
    strealm_mock_cs.strealm._update_stream_balance(owner);
    strealm_mock_cs.strealm._update_stream_balance(owner);
    strealm_mock_cs.strealm._update_stream_balance(owner);
    strealm_mock_cs.strealm._update_stream_balance(owner);

    // expected balance should remain the same
    let expected_balance = (_40_seconds_later.into() - stream.start_at.into())
        * owner_nft_count.into()
        * FLOW_RATE();

    // ensure saved balance is expected balance
    assert_eq!(strealm_mock_cs.strealm.StRealm_staker_reward_balance.read(owner), expected_balance);
}


#[test]
fn test_internal_reward_claim() {
    let mut erc20_mock_dispatcher = ERC20_MOCK();
    let mut strealm_mock_cs = STREALM_CONTRACT_STATE();
    ///
    ///  start setup
    /// 

    // use erc20 mock as reward token
    strealm_mock_cs.strealm._update_reward_token(erc20_mock_dispatcher.contract_address);

    // give test address allowance to spend reward token
    start_prank(CheatTarget::One(erc20_mock_dispatcher.contract_address), REWARD_PAYER());
    erc20_mock_dispatcher.approve(test_address(), BoundedInt::max());
    stop_prank(CheatTarget::One(erc20_mock_dispatcher.contract_address));

    // ensure owner's erc20 reward balance is 0
    let owner = contract_address_const::<'ownerx'>();
    assert_eq!(erc20_mock_dispatcher.balance_of(owner), 0);

    // add to the owner's reward balance
    let reward = 156_000;
    strealm_mock_cs.strealm.StRealm_staker_reward_balance.write(owner, reward);

    ///
    ///  end  setup
    /// 

    // make claim
    strealm_mock_cs.strealm._reward_claim(owner);

    // ensure internal reward balance is cleared
    assert_eq!(strealm_mock_cs.strealm.StRealm_staker_reward_balance.read(owner), 0);
    assert_eq!(erc20_mock_dispatcher.balance_of(owner), reward);
}

#[test]
#[should_panic(expected: ('StRealm: zero reward balance',))]
fn test_internal_reward_claim_zero_amount() {
    let mut erc20_mock_dispatcher = ERC20_MOCK();
    let mut strealm_mock_cs = STREALM_CONTRACT_STATE();
    ///
    ///  start setup
    /// 

    // ensure owner's erc20 reward balance is 0
    let owner = contract_address_const::<'ownerx'>();
    assert_eq!(erc20_mock_dispatcher.balance_of(owner), 0);

    ///
    ///  end  setup
    /// 

    // make claim
    strealm_mock_cs.strealm._reward_claim(owner);
}


/// 
/// 
/// External/ Public  functions Tests
/// 
/// 

#[test]
fn test_external_reward_claim() {
    let mut erc20_mock_dispatcher = ERC20_MOCK();
    let mut strealm_mock_cs = STREALM_CONTRACT_STATE();
    ///
    ///  start setup
    /// 

    // use erc20 mock as reward token
    strealm_mock_cs.strealm._update_reward_token(erc20_mock_dispatcher.contract_address);

    // give test address allowance to spend reward token
    start_prank(CheatTarget::One(erc20_mock_dispatcher.contract_address), REWARD_PAYER());
    erc20_mock_dispatcher.approve(test_address(), BoundedInt::max());
    stop_prank(CheatTarget::One(erc20_mock_dispatcher.contract_address));

    // ensure owner's erc20 reward balance is 0
    let owner = contract_address_const::<'ownerx'>();
    assert_eq!(erc20_mock_dispatcher.balance_of(owner), 0);

    // add to the owner's reward balance
    let reward = 156_000;
    strealm_mock_cs.strealm.StRealm_staker_reward_balance.write(owner, reward);

    ///
    ///  end  setup
    /// 

    // make claim
    start_prank(CheatTarget::One(test_address()), owner);
    strealm_mock_cs.strealm.reward_claim();
    stop_prank(CheatTarget::One(test_address()));

    // ensure erc20 balance is accrate
    assert_eq!(erc20_mock_dispatcher.balance_of(owner), reward);
}


#[test]
fn test_external_update_flow_rate() {
    let mut strealm_mock_cs = STREALM_CONTRACT_STATE();

    let caller = contract_address_const::<'callerx'>();
    strealm_mock_cs.access_control._grant_role(StRealmComponent::DEFAULT_ADMIN_ROLE, caller);
    start_prank(CheatTarget::One(test_address()), caller);

    // update flow rate 
    let new_flow_rate = 777;
    strealm_mock_cs.strealm.update_flow_rate(new_flow_rate);

    // check that new flow rate has been added
    let latest_flow_id: u64 = strealm_mock_cs.strealm.get_latest_flow_id();
    assert_eq!(latest_flow_id, 2);

    let latest_flow: Flow = strealm_mock_cs.strealm.get_flow(latest_flow_id);
    assert_eq!(latest_flow.rate, new_flow_rate);
    assert_eq!(latest_flow.end_at, BoundedInt::max());
}


#[test]
#[should_panic(expected: ('Caller is missing role',))]
fn test_external_update_flow_rate_no_permission() {
    let mut strealm_mock_cs = STREALM_CONTRACT_STATE();

    let caller = contract_address_const::<'callerx'>();
    // strealm_mock_cs.access_control._grant_role(StRealmComponent::DEFAULT_ADMIN_ROLE, caller);
    start_prank(CheatTarget::One(test_address()), caller);

    // update flow rate 
    let new_flow_rate = 777;
    strealm_mock_cs.strealm.update_flow_rate(new_flow_rate);

    // check that new flow rate has been added
    let latest_flow_id: u64 = strealm_mock_cs.strealm.get_latest_flow_id();
    assert_eq!(latest_flow_id, 2);

    let latest_flow: Flow = strealm_mock_cs.strealm.get_flow(latest_flow_id);
    assert_eq!(latest_flow.rate, new_flow_rate);
    assert_eq!(latest_flow.end_at, BoundedInt::max());
}


#[test]
fn test_external_update_reward_payer() {
    let mut strealm_mock_cs = STREALM_CONTRACT_STATE();

    let caller = contract_address_const::<'callerx'>();
    strealm_mock_cs.access_control._grant_role(StRealmComponent::DEFAULT_ADMIN_ROLE, caller);
    start_prank(CheatTarget::One(test_address()), caller);

    let new_reward_payer = contract_address_const::<'new_payer'>();
    strealm_mock_cs.strealm.update_reward_payer(new_reward_payer);
    assert_eq!(strealm_mock_cs.strealm.get_reward_payer(), new_reward_payer);
}


#[test]
#[should_panic(expected: ('Caller is missing role',))]
fn test_external_update_reward_payer_no_permission() {
    let mut strealm_mock_cs = STREALM_CONTRACT_STATE();

    let caller = contract_address_const::<'callerx'>();
    // strealm_mock_cs.access_control._grant_role(StRealmComponent::DEFAULT_ADMIN_ROLE, caller);
    start_prank(CheatTarget::One(test_address()), caller);

    let new_reward_payer = contract_address_const::<'new_payer'>();
    strealm_mock_cs.strealm.update_reward_payer(new_reward_payer);
    assert_eq!(strealm_mock_cs.strealm.get_reward_payer(), new_reward_payer);
}


#[test]
fn test_external_get_stream() {
    let mut strealm_mock_cs = STREALM_CONTRACT_STATE();
    let owner = contract_address_const::<'ownerx'>();
    let stream = Stream { start_at: 99, flow_id: 99 };
    strealm_mock_cs.strealm.StRealm_streams.write(owner, stream);

    assert_eq!(strealm_mock_cs.get_stream(owner).start_at, stream.start_at);
    assert_eq!(strealm_mock_cs.get_stream(owner).flow_id, stream.flow_id);
}

#[test]
fn test_external_get_flow() {
    let mut strealm_mock_cs = STREALM_CONTRACT_STATE();
    let flow_id = 14;
    let flow = Flow { end_at: 99, rate: 99 };
    strealm_mock_cs.strealm.StRealm_flows.write(flow_id, flow);

    assert_eq!(strealm_mock_cs.get_flow(flow_id).end_at, flow.end_at);
    assert_eq!(strealm_mock_cs.get_flow(flow_id).rate, flow.rate);
}

#[test]
fn test_external_get_latest_flow_id() {
    let mut strealm_mock_cs = STREALM_CONTRACT_STATE();
    strealm_mock_cs.strealm.StRealm_latest_flow_id.write(44);
    assert_eq!(strealm_mock_cs.get_latest_flow_id(), 44);
}

#[test]
fn test_external_get_reward_token() {
    let mut strealm_mock_cs = STREALM_CONTRACT_STATE();
    let token_addr = contract_address_const::<'tokenx'>();
    strealm_mock_cs.strealm.StRealm_reward_token.write(token_addr);
    assert_eq!(strealm_mock_cs.get_reward_token(), token_addr);
}

#[test]
fn test_external_get_reward_payer() {
    let mut strealm_mock_cs = STREALM_CONTRACT_STATE();
    let payer_addr = contract_address_const::<'payerx'>();
    strealm_mock_cs.strealm.StRealm_reward_payer.write(payer_addr);
    assert_eq!(strealm_mock_cs.get_reward_payer(), payer_addr);
}

#[test]
fn test_external_get_reward_balance() {
    let mut strealm_mock_cs = STREALM_CONTRACT_STATE();

    /// setup
    let owner: ContractAddress = contract_address_const::<'ownerx'>();
    let stream: Stream = Stream {
        start_at: 1, flow_id: strealm_mock_cs.strealm.get_latest_flow_id()
    };
    strealm_mock_cs.strealm.StRealm_streams.write(owner, stream);
    // set give caller x nfts 
    let owner_nft_count = 2_u256;
    strealm_mock_cs.erc721.ERC721_balances.write(owner, owner_nft_count);
    ///  end  setup

    // move 40 seconds into the future
    let _40_seconds_later = stream.start_at + 40_u64;
    start_warp(CheatTarget::One(test_address()), _40_seconds_later);
    // get reward balance
    let expected_balance = (_40_seconds_later.into() - stream.start_at.into())
        * owner_nft_count.into()
        * FLOW_RATE();

    // ensure actual balance is expected balance
    start_prank(CheatTarget::One(test_address()), owner);
    assert_eq!(strealm_mock_cs.strealm.get_reward_balance(), expected_balance);
}

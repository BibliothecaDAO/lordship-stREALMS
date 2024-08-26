use lordship::interfaces::IERC20::{IERC20Dispatcher, IERC20DispatcherTrait};
use lordship::interfaces::IRewardPool::{IRewardPoolDispatcher, IRewardPoolDispatcherTrait};
use lordship::interfaces::IVE::IVEDispatcherTrait;
use lordship::tests::common;
use snforge_std::{start_prank, start_warp, stop_prank, CheatTarget};
use starknet::{ContractAddress, get_block_timestamp, get_contract_address};

#[test]
fn test_reward_pool_claim_pass() {
    let (velords, lords) = common::velords_setup();
    let reward_pool = IRewardPoolDispatcher { contract_address: velords.get_reward_pool() };
    let blobert: ContractAddress = common::blobert();
    common::setup_for_blobert(lords.contract_address, velords.contract_address);
    let loaf: ContractAddress = common::loaf();
    common::setup_for_loaf(lords.contract_address, velords.contract_address);

    let blobert_lock_amount: u256 = 2_000_000 * common::ONE;
    let loaf_lock_amount: u256 = 1_000_000 * common::ONE;
    let now = get_block_timestamp();
    let unlock_time: u64 = now + 4 * common::YEAR;

    // blobert locks 2M LORDS for 4 years
    start_prank(CheatTarget::One(velords.contract_address), blobert);
    velords.manage_lock(blobert_lock_amount, unlock_time, blobert);

    // loaf locks 1M LORDS for 4 years
    start_prank(CheatTarget::One(velords.contract_address), loaf);
    velords.manage_lock(loaf_lock_amount, unlock_time, loaf);

    // simulate rewards going to the reward pool
    let this = get_contract_address();
    start_prank(CheatTarget::All, this);
    let rewards: u256 = 500_000 * common::ONE;
    common::fund_lords(this, Option::Some(rewards));
    lords.approve(reward_pool.contract_address, rewards);

    start_warp(CheatTarget::All, now + common::DAY * 30);
    velords.checkpoint();
    reward_pool.checkpoint_total_supply();
    reward_pool.burn(rewards);

    start_warp(CheatTarget::All, now + common::DAY * 60);

    // loaf claims rewards
    start_prank(CheatTarget::One(reward_pool.contract_address), loaf);
    let loaf_rewards = reward_pool.claim(loaf);
    common::assert_approx(loaf_rewards, rewards / 3, common::ONE * 10, "loaf rewards mismatch");

    // loaf claims blobert's rewards (tests claiming on behalf of another account)
    let blobert_rewards = reward_pool.claim(blobert);
    common::assert_approx(blobert_rewards, rewards * 2 / 3, common::ONE * 10, "blobert rewards mismatch");

    // all rewards claimed
    common::assert_approx(loaf_rewards + blobert_rewards, rewards, common::ONE * 10, "total rewards mismatch");
    let reward_pool_balance = lords.balance_of(reward_pool.contract_address);
    common::assert_approx(reward_pool_balance, 0, common::ONE * 10, "reward pool balance mismatch");
}

#[test]
fn test_flow_issue() {
    // test of a flow that Redbeard reported as ending in a TX error
    let (velords, lords) = common::velords_setup();
    let reward_pool = IRewardPoolDispatcher { contract_address: velords.get_reward_pool() };
    let blobert: ContractAddress = common::blobert();
    common::setup_for_blobert(lords.contract_address, velords.contract_address);

    let lock_amount: u256 = 2_000_000 * common::ONE;
    let now = get_block_timestamp();

    // blobert locks 2M LORDS for 1 year
    start_prank(CheatTarget::One(velords.contract_address), blobert);
    velords.manage_lock(lock_amount, now + common::YEAR, blobert);

    // time passes, blobert paperhand withdraws early
    let now = now + 14 * common::DAY;
    start_warp(CheatTarget::All, now);
    velords.withdraw();

    // time passes, blobert locks some more again
    let now = now + 20 * common::DAY;
    start_warp(CheatTarget::All, now);
    velords.manage_lock(500 * common::ONE, now + 30 * common::DAY, blobert);

    // time passes, blobert decides to extend the lock
    let now = now + 5 * common::DAY;
    start_warp(CheatTarget::All, now);
    velords.manage_lock(0, now + 2 * common::YEAR, blobert);

    // blobert calls burn, because why not
    start_prank(CheatTarget::One(lords.contract_address), blobert);
    lords.approve(reward_pool.contract_address, 500_000 * common::ONE);
    stop_prank(CheatTarget::One(lords.contract_address));
    start_prank(CheatTarget::One(reward_pool.contract_address), blobert);
    reward_pool.burn(500_000 * common::ONE);

    // time passes, blobert claims rewards
    let now = now + 7 * common::DAY;
    start_warp(CheatTarget::All, now);
    let _reward = reward_pool.claim(blobert);
}

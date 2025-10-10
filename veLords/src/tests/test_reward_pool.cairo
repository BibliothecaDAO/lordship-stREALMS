use lordship::interfaces::IERC20::{IERC20Dispatcher, IERC20DispatcherTrait};
use lordship::interfaces::IRewardPool::{IRewardPoolDispatcher, IRewardPoolDispatcherTrait};
use lordship::interfaces::IVE::IVEDispatcherTrait;
use lordship::tests::common;
use snforge_std::{start_prank, start_warp, stop_prank, CheatTarget};
use starknet::{ContractAddress, get_block_timestamp, get_contract_address};

#[test]
fn test_reward_pool_claim_without_keeper_checkpoint() {
    let (velords, lords) = common::velords_setup();
    let reward_pool = IRewardPoolDispatcher { contract_address: velords.get_reward_pool() };
    let blobert: ContractAddress = common::blobert();
    common::setup_for_blobert(lords.contract_address, velords.contract_address);
    let loaf: ContractAddress = common::loaf();
    common::setup_for_loaf(lords.contract_address, velords.contract_address);

    let blobert_lock_amount: u256 = 2_000_000 * common::ONE;
    let loaf_lock_amount: u256 = 1_000_000 * common::ONE;
    let deployment_ts = get_block_timestamp();
    let unlock_time: u64 = deployment_ts + 4 * common::YEAR;

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

    start_warp(CheatTarget::All, deployment_ts + common::DAY * 30);
    velords.checkpoint();
    reward_pool.checkpoint_total_supply();
    reward_pool.burn(rewards);

    start_warp(CheatTarget::All, deployment_ts + common::DAY * 60);

    // loaf claims rewards
    start_prank(CheatTarget::One(reward_pool.contract_address), loaf);
    let loaf_rewards = reward_pool.claim(loaf);

    // Timeline recap (UTC):
    // - Deployment timestamp = Sat 09 Mar 2024 16:00; `floor_to_week` lands on Thu 07 Mar 2024 00:00, so `last_token_time` stays at that week-0 boundary.
    // - We burn 500k LORDS on Tue 08 Apr 2024 16:00 (deployment + 30 days), which is 2_822_400 s after the week-0 boundary = 4 full weeks + 4/7 of a week.
    // - Week 0 (Thu 07 Mar → Thu 14 Mar) therefore captures 604_800 / 2_822_400 = 3/14 of the rewards. Loaf and Blobert do lock during that window,
    //   but `week_cursor` for each account skips straight to week 1, so none of them ever iterate week 0 and that 3/14 stays burned forever in the pool.
    let amount_lost_to_week0: u256 = rewards * 3 / 14_u256;
    let expected_claimable: u256 = rewards - amount_lost_to_week0;
    let expected_loaf: u256 = expected_claimable
        / 3_u128.into(); // loaf is entitled to 1/3 of shares since he has 1/3 of deposits 
    common::assert_approx(loaf_rewards, expected_loaf, common::ONE * 10, "loaf rewards mismatch");

    // loaf claims blobert's rewards (tests claiming on behalf of another account)
    let blobert_rewards = reward_pool.claim(blobert);
    let expected_blobert: u256 = expected_claimable - expected_loaf;
    common::assert_approx(blobert_rewards, expected_blobert, common::ONE * 10, "blobert rewards mismatch");

    // all rewards claimed
    let total_claimed: u256 = loaf_rewards + blobert_rewards;
    common::assert_approx(total_claimed, expected_claimable, common::ONE * 10, "total rewards mismatch");
    let reward_pool_balance = lords.balance_of(reward_pool.contract_address);
    let expected_unclaimed: u256 = rewards - expected_claimable;
    common::assert_approx(reward_pool_balance, expected_unclaimed, common::ONE * 10, "reward pool balance mismatch");
}


#[test]
fn test_reward_pool_claim_with_keeper_checkpoint() {
    let (velords, lords) = common::velords_setup();
    let reward_pool = IRewardPoolDispatcher { contract_address: velords.get_reward_pool() };
    let blobert: ContractAddress = common::blobert();
    common::setup_for_blobert(lords.contract_address, velords.contract_address);
    let loaf: ContractAddress = common::loaf();
    common::setup_for_loaf(lords.contract_address, velords.contract_address);

    let blobert_lock_amount: u256 = 2_000_000 * common::ONE;
    let loaf_lock_amount: u256 = 1_000_000 * common::ONE;
    let deployment_ts = get_block_timestamp();
    let unlock_time: u64 = deployment_ts + 4 * common::YEAR;

    // blobert locks 2M LORDS for 4 years
    start_prank(CheatTarget::One(velords.contract_address), blobert);
    velords.manage_lock(blobert_lock_amount, unlock_time, blobert);

    // loaf locks 1M LORDS for 4 years
    start_prank(CheatTarget::One(velords.contract_address), loaf);
    velords.manage_lock(loaf_lock_amount, unlock_time, loaf);

    // Keeper timeline (UTC):
    // - We warp to Thu 14 Mar 2024 00:00 (first boundary after deployment) and call `checkpoint_token`,
    //   which bumps `last_token_time` forward to week 1 before any rewards arrive.
    // - The burn still happens Tue 08 Apr 2024 16:00, so the accounting window now covers only weeks 1‒4⅔ and
    //   every week we iterate has matching ve-supply, making the entire 500k LORDS claimable.
    let first_full_week = common::floor_to_week(deployment_ts) + common::WEEK;
    start_warp(CheatTarget::All, first_full_week);
    reward_pool.checkpoint_token();

    // simulate rewards going to the reward pool
    let this = get_contract_address();
    start_prank(CheatTarget::All, this);
    let rewards: u256 = 500_000 * common::ONE;
    common::fund_lords(this, Option::Some(rewards));
    lords.approve(reward_pool.contract_address, rewards);

    start_warp(CheatTarget::All, deployment_ts + common::DAY * 30);
    velords.checkpoint();
    reward_pool.checkpoint_total_supply();
    reward_pool.burn(rewards);

    start_warp(CheatTarget::All, deployment_ts + common::DAY * 60);

    // loaf claims rewards
    start_prank(CheatTarget::One(reward_pool.contract_address), loaf);
    let loaf_rewards = reward_pool.claim(loaf);
    let expected_loaf: u256 = rewards
        / 3_u128.into(); // loaf is entitled to 1/3 of shares since he has 1/3 of deposits 
    common::assert_approx(loaf_rewards, expected_loaf, common::ONE * 10, "loaf rewards mismatch");

    // loaf claims blobert's rewards (tests claiming on behalf of another account)
    let blobert_rewards = reward_pool.claim(blobert);
    let expected_blobert: u256 = rewards - expected_loaf;
    common::assert_approx(blobert_rewards, expected_blobert, common::ONE * 10, "blobert rewards mismatch");

    // all rewards claimed
    let total_claimed: u256 = loaf_rewards + blobert_rewards;
    common::assert_approx(total_claimed, rewards, common::ONE * 10, "total rewards mismatch");
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

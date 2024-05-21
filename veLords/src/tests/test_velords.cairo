use lordship::interfaces::IERC20::{IERC20Dispatcher, IERC20DispatcherTrait};
use lordship::interfaces::IVE::{IVEDispatcher, IVEDispatcherTrait};
use lordship::tests::common;
use lordship::tests::common::assert_approx;
use lordship::velords::Lock;
use openzeppelin::access::ownable::interface::{IOwnableDispatcher, IOwnableDispatcherTrait};
use snforge_std::{load, start_prank, start_warp, stop_prank, CheatTarget};
use starknet::{ContractAddress, Store, get_block_timestamp};
use starknet::storage_access::StorePacking;

#[test]
fn test_lock_packing() {
    let amount: u128 = 0x100000000000000000000;
    let end_time: u64 = 1700000000;
    let lock = Lock { amount, end_time };
    let packed: felt252 = StorePacking::pack(lock);
    let unpacked: Lock = StorePacking::unpack(packed);
    assert!(lock.amount == unpacked.amount, "amount mismatch");
    assert!(lock.end_time == unpacked.end_time, "end time mismatch");
}

#[test]
fn test_velords_setup() {
    let velords = IERC20Dispatcher { contract_address: common::deploy_velords() };
    assert_eq!(velords.name(), "Voting LORDS", "name mismatch");
    assert_eq!(velords.symbol(), "veLORDS", "symbol mismatch");
    assert_eq!(velords.decimals(), 18, "decimals mismatch");
    assert_eq!(velords.total_supply(), 0, "total supply mismatch");

    let owner = common::velords_owner();
    assert_eq!(IOwnableDispatcher { contract_address: velords.contract_address }.owner(), owner, "owner mismatch");
}

#[test]
#[should_panic(expected: "veLORDS are non-transferable")]
fn test_velords_non_transferable() {
    let velords = IERC20Dispatcher { contract_address: common::deploy_velords() };
    let owner: ContractAddress = common::velords_owner();
    let spender: ContractAddress = 'king'.try_into().unwrap();

    start_prank(CheatTarget::One(velords.contract_address), owner);
    // testing approve() returns false in here too
    assert_eq!(velords.approve(spender, 100), false, "approve should not be available");

    velords.transfer(spender, 1); // should panic
}

#[test]
fn test_create_new_lock_pass() {
    let (velords, lords) = common::velords_setup();
    let velords_token = IERC20Dispatcher { contract_address: velords.contract_address };
    let blobert: ContractAddress = common::blobert();
    common::setup_for_blobert(lords.contract_address, velords.contract_address);

    let balance: u256 = 10_000_000 * common::ONE;
    let lock_amount: u256 = 2_000_000 * common::ONE;
    let now = get_block_timestamp();
    let unlock_time: u64 = now + common::YEAR;

    // sanity checks
    assert_eq!(lords.balance_of(blobert), balance, "balance mismatch");
    assert_eq!(lords.allowance(blobert, velords.contract_address), balance, "allowance mismatch");
    assert_eq!(velords_token.total_supply(), 0, "total supply mismatch");

    // blobert locks 2M LORDS for 1 year
    start_prank(CheatTarget::One(velords.contract_address), blobert);
    velords.manage_lock(lock_amount, unlock_time, blobert);

    assert_eq!(lords.balance_of(blobert), balance - lock_amount, "LORDS balance mismatch after locking");
    assert_eq!(velords_token.total_supply(), velords_token.balance_of(blobert), "total supply mismatch after locking");
    assert_approx(
        velords_token.balance_of(blobert),
        common::lock_balance(lock_amount, common::YEAR),
        common::day_decline_of(lock_amount) * 7,
        "blobert's veLORDS balance mismatch after locking"
    );
    let lock: Lock = velords.get_lock_for(blobert);
    assert_eq!(lock.amount, lock_amount.try_into().unwrap(), "lock amount mismatch");
    assert_eq!(lock.end_time, common::floor_to_week(unlock_time), "unlock time mismatch");
    // TODO: test events
}

#[test]
fn test_create_new_lock_capped_4y_pass() {
    let (velords, lords) = common::velords_setup();
    let velords_token = IERC20Dispatcher { contract_address: velords.contract_address };
    let blobert: ContractAddress = common::blobert();
    common::setup_for_blobert(lords.contract_address, velords.contract_address);

    let balance: u256 = 10_000_000 * common::ONE;
    let lock_amount: u256 = 2_000_000 * common::ONE;
    let now = get_block_timestamp();
    let unlock_time: u64 = now + 20 * common::YEAR;
    let capped_unlock_time: u64 = now + 4 * common::YEAR;

    // blobert locks 2M LORDS for 20 years, will be capped to 4
    start_prank(CheatTarget::One(velords.contract_address), blobert);
    velords.manage_lock(lock_amount, unlock_time, blobert);

    assert_eq!(lords.balance_of(blobert), balance - lock_amount, "LORDS balance mismatch after locking");
    assert_eq!(velords_token.total_supply(), velords_token.balance_of(blobert), "total supply mismatch after locking");
    assert_approx(
        velords_token.balance_of(blobert),
        common::lock_balance(lock_amount, 4 * common::YEAR),
        common::day_decline_of(lock_amount) * 7,
        "blobert's veLORDS balance mismatch after locking"
    );
    let lock: Lock = velords.get_lock_for(blobert);
    assert_eq!(lock.amount, lock_amount.try_into().unwrap(), "lock amount mismatch");
    assert_eq!(lock.end_time, common::floor_to_week(capped_unlock_time), "unlock time mismatch");
}

#[test]
#[should_panic(expected: "must lock amount greater than zero")]
fn test_create_new_lock_zero_amount_fail() {
    let velords = IVEDispatcher { contract_address: common::deploy_velords() };
    let blobert: ContractAddress = common::blobert();

    start_warp(CheatTarget::All, common::TS);
    start_prank(CheatTarget::One(velords.contract_address), blobert);

    let now = get_block_timestamp();
    let unlock_time: u64 = now + common::YEAR;

    velords.manage_lock(0, unlock_time, blobert);
}

#[test]
#[should_panic(expected: "must set unlock time")]
fn test_create_new_lock_unlock_time_zero_fail() {
    let velords = IVEDispatcher { contract_address: common::deploy_velords() };
    let blobert: ContractAddress = common::blobert();

    start_warp(CheatTarget::All, common::TS);
    start_prank(CheatTarget::One(velords.contract_address), blobert);

    let lock_amount: u256 = 100_000 * common::ONE;

    velords.manage_lock(lock_amount, 0, blobert);
}

#[test]
#[should_panic(expected: "unlock time must be in the future")]
fn test_create_new_lock_in_past_fail() {
    let velords = IVEDispatcher { contract_address: common::deploy_velords() };
    let blobert: ContractAddress = common::blobert();

    start_warp(CheatTarget::All, common::TS);
    start_prank(CheatTarget::One(velords.contract_address), blobert);

    let now = get_block_timestamp();
    let unlock_time: u64 = now - common::YEAR;

    velords.manage_lock(0, unlock_time, blobert);
}

#[test]
#[should_panic(expected: "can create a lock only for oneself")]
fn test_create_new_lock_for_others_fail() {
    let velords = IVEDispatcher { contract_address: common::deploy_velords() };
    let blobert: ContractAddress = common::blobert();
    let badguy: ContractAddress = common::badguy();

    start_warp(CheatTarget::All, common::TS);
    start_prank(CheatTarget::One(velords.contract_address), badguy);

    let lock_amount: u256 = 100_000 * common::ONE;
    let now = get_block_timestamp();
    let unlock_time: u64 = now + common::YEAR;

    velords.manage_lock(lock_amount, unlock_time, blobert);
}

#[test]
fn test_modify_lock_new_amount_and_time_pass() {
    let (velords, lords) = common::velords_setup();
    let velords_token = IERC20Dispatcher { contract_address: velords.contract_address };
    let blobert: ContractAddress = common::blobert();
    common::setup_for_blobert(lords.contract_address, velords.contract_address);

    let balance: u256 = 10_000_000 * common::ONE;
    let lock_amount: u256 = 2_000_000 * common::ONE;
    let now = get_block_timestamp();
    let unlock_time: u64 = now + common::YEAR;

    // blobert locks 2M LORDS for 1 year
    start_prank(CheatTarget::One(velords.contract_address), blobert);
    velords.manage_lock(lock_amount, unlock_time, blobert);

    assert_eq!(lords.balance_of(blobert), balance - lock_amount, "LORDS balance mismatch after locking 1");
    assert_eq!(velords_token.total_supply(), velords_token.balance_of(blobert), "total supply mismatch after locking 1");

    // blobert lock 1M more LORDS
    let next_lock_amount: u256 = 1_000_000 * common::ONE;
    let unlock_time: u64 = unlock_time + common::WEEK;
    velords.manage_lock(next_lock_amount, unlock_time, blobert);

    let total_lock_amount: u256 = lock_amount + next_lock_amount;
    assert_eq!(lords.balance_of(blobert), balance - total_lock_amount, "LORDS balance mismatch after locking 2");
    assert_eq!(velords_token.total_supply(), velords_token.balance_of(blobert), "total supply mismatch after locking 2");
    assert_approx(
        velords_token.balance_of(blobert),
        common::lock_balance(total_lock_amount, common::YEAR + common::WEEK),
        common::day_decline_of(total_lock_amount) * 7,
        "blobert's veLORDS balance mismatch after locking 2"
    );
    let lock: Lock = velords.get_lock_for(blobert);
    assert_eq!(lock.amount, total_lock_amount.try_into().unwrap(), "lock amount mismatch 2");
    assert_eq!(lock.end_time, common::floor_to_week(unlock_time), "unlock time mismatch 2");

    // blobert extends the lock by 1 more year
    let unlock_time: u64 = unlock_time + common::YEAR;
    velords.manage_lock(0, unlock_time, blobert);

    assert_eq!(lords.balance_of(blobert), balance - total_lock_amount, "LORDS balance mismatch after locking 3");
    assert_eq!(velords_token.total_supply(), velords_token.balance_of(blobert), "total supply mismatch after locking 3");
    assert_approx(
        velords_token.balance_of(blobert),
        common::lock_balance(total_lock_amount, common::YEAR * 2 + common::WEEK),
        common::day_decline_of(total_lock_amount) * 7,
        "blobert's veLORDS balance mismatch after locking 3"
    );
    let lock: Lock = velords.get_lock_for(blobert);
    assert_eq!(lock.amount, total_lock_amount.try_into().unwrap(), "lock amount mismatch 3");
    assert_eq!(lock.end_time, common::floor_to_week(unlock_time), "unlock time mismatch 3");

    // blobert adds 3M more LORDS and extends the lock by 1 more year
    let next_lock_amount: u256 = 3_000_000 * common::ONE;
    let unlock_time: u64 = unlock_time + common::YEAR;
    velords.manage_lock(next_lock_amount, unlock_time, blobert);

    let total_lock_amount: u256 = total_lock_amount + next_lock_amount;
    assert_eq!(lords.balance_of(blobert), balance - total_lock_amount, "LORDS balance mismatch after locking 4");
    assert_eq!(velords_token.total_supply(), velords_token.balance_of(blobert), "total supply mismatch after locking 4");
    assert_approx(
        velords_token.balance_of(blobert),
        common::lock_balance(total_lock_amount, common::YEAR * 3 + common::WEEK),
        common::day_decline_of(total_lock_amount) * 7,
        "blobert's veLORDS balance mismatch after locking 4"
    );
    let lock: Lock = velords.get_lock_for(blobert);
    assert_eq!(lock.amount, total_lock_amount.try_into().unwrap(), "lock amount mismatch 4");
    assert_eq!(lock.end_time, common::floor_to_week(unlock_time), "unlock time mismatch 4");
}

#[test]
#[should_panic(expected: "unlock time must be in the future")]
fn test_unlock_time_in_past_fail() {
    let (velords, lords) = common::velords_setup();
    let blobert: ContractAddress = common::blobert();
    common::setup_for_blobert(lords.contract_address, velords.contract_address);

    let lock_amount: u256 = 2_000_000 * common::ONE;
    let now = get_block_timestamp();
    let unlock_time: u64 = now - common::DAY;

    // blobert tries to lock in the past
    start_prank(CheatTarget::One(velords.contract_address), blobert);
    velords.manage_lock(lock_amount, unlock_time, blobert);
}

#[test]
#[should_panic(expected: "new unlock time must be greater than current unlock time")]
fn test_shorten_lock_time_fail() {
    let (velords, lords) = common::velords_setup();
    let blobert: ContractAddress = common::blobert();
    common::setup_for_blobert(lords.contract_address, velords.contract_address);

    let balance: u256 = 10_000_000 * common::ONE;
    let lock_amount: u256 = 2_000_000 * common::ONE;
    let now = get_block_timestamp();
    let unlock_time: u64 = now + common::YEAR;

    // blobert locks 2M LORDS for 1 year
    start_prank(CheatTarget::One(velords.contract_address), blobert);
    velords.manage_lock(lock_amount, unlock_time, blobert);

    // sanity check
    assert_eq!(lords.balance_of(blobert), balance - lock_amount, "LORDS balance mismatch after locking");

    // blobert tries to shorten the lock time
    velords.manage_lock(0, unlock_time - common::DAY, blobert);
}

#[test]
#[should_panic(expected: "cannot modify an expired lock")]
fn test_modifying_expired_lock_fail() {
    let (velords, lords) = common::velords_setup();
    let blobert: ContractAddress = common::blobert();
    common::setup_for_blobert(lords.contract_address, velords.contract_address);

    let lock_amount: u256 = 2_000_000 * common::ONE;
    let now = get_block_timestamp();
    let unlock_time: u64 = now + common::WEEK * 4;

    // blobert locks 2M LORDS for 4 weeks
    start_prank(CheatTarget::One(velords.contract_address), blobert);
    velords.manage_lock(lock_amount, unlock_time, blobert);

    // sanity check
    let lock: Lock = velords.get_lock_for(blobert);
    assert_eq!(lock.amount, lock_amount.try_into().unwrap(), "lock amount mismatch");
    assert_eq!(lock.end_time, common::floor_to_week(unlock_time), "unlock time mismatch");

    // move time forward 2 months, lock is expired
    start_warp(CheatTarget::All, now + common::WEEK * 8);

    // blobert tries to lock 2M more LORDS for 1 year
    velords.manage_lock(lock_amount, now + common::YEAR, blobert);
}

#[test]
fn test_modify_lock_amount_by_non_owner_pass() {
    let (velords, lords) = common::velords_setup();
    let velords_token = IERC20Dispatcher { contract_address: velords.contract_address };
    let blobert: ContractAddress = common::blobert();
    common::setup_for_blobert(lords.contract_address, velords.contract_address);

    let lock_amount: u256 = 2_000_000 * common::ONE;
    let now = get_block_timestamp();
    let unlock_time: u64 = now + common::YEAR;

    // blobert locks 2M LORDS for 1 year
    start_prank(CheatTarget::One(velords.contract_address), blobert);
    velords.manage_lock(lock_amount, unlock_time, blobert);

    // sanity check
    assert_eq!(velords_token.total_supply(), velords_token.balance_of(blobert), "total supply mismatch after locking 1");
    assert_approx(
        velords_token.balance_of(blobert),
        common::lock_balance(lock_amount, common::YEAR),
        common::day_decline_of(lock_amount) * 7,
        "blobert's veLORDS balance mismatch after locking 1"
    );

    // loaf adds 2M LORDS to blobert's lock
    let loaf: ContractAddress = common::loaf();
    let amount_added: u256 = 2_000_000 * common::ONE;
    common::fund_lords(loaf, Option::Some(amount_added));

    start_prank(CheatTarget::One(lords.contract_address), loaf);
    lords.approve(velords.contract_address, amount_added);
    stop_prank(CheatTarget::All);
    start_prank(CheatTarget::One(velords.contract_address), loaf);
    velords.manage_lock(amount_added, 0, blobert);

    assert_eq!(velords_token.total_supply(), velords_token.balance_of(blobert), "total supply mismatch after locking 2");
    assert_approx(
        velords_token.balance_of(blobert),
        common::lock_balance(lock_amount + amount_added, common::YEAR),
        common::day_decline_of(lock_amount + amount_added) * 7,
        "blobert's veLORDS balance mismatch after locking 2"
    );
    // TODO: events
}

#[test]
fn test_modify_lock_time_by_non_owner_noop() {
    let (velords, lords) = common::velords_setup();
    let velords_token = IERC20Dispatcher { contract_address: velords.contract_address };
    let blobert: ContractAddress = common::blobert();
    common::setup_for_blobert(lords.contract_address, velords.contract_address);

    let lock_amount: u256 = 2_000_000 * common::ONE;
    let now = get_block_timestamp();
    let unlock_time: u64 = now + common::YEAR;

    // blobert locks 2M LORDS for 1 year
    start_prank(CheatTarget::One(velords.contract_address), blobert);
    velords.manage_lock(lock_amount, unlock_time, blobert);

    // sanity check
    assert_eq!(velords_token.total_supply(), velords_token.balance_of(blobert), "total supply mismatch after locking 1");
    assert_approx(
        velords_token.balance_of(blobert),
        common::lock_balance(lock_amount, common::YEAR),
        common::day_decline_of(lock_amount) * 7,
        "blobert's veLORDS balance mismatch after locking 1"
    );

    // badguy tries to extend the lock time, nothing happens
    start_prank(CheatTarget::One(velords.contract_address), common::badguy());
    velords.manage_lock(0, unlock_time + common::YEAR * 3, blobert);

    let lock: Lock = velords.get_lock_for(blobert);
    assert_eq!(lock.amount, lock_amount.try_into().unwrap(), "lock amount mismatch");
    assert_eq!(lock.end_time, common::floor_to_week(unlock_time), "unlock time mismatch");
}

#[test]
fn test_locked_balance_progression() {
    // TODO: this test fails, fix it

    let (velords, lords) = common::velords_setup();
    let velords_token = IERC20Dispatcher { contract_address: velords.contract_address };
    let blobert: ContractAddress = common::blobert();
    common::setup_for_blobert(lords.contract_address, velords.contract_address);

    let balance: u256 = 10_000_000 * common::ONE;
    let lock_amount: u256 = 2_000_000 * common::ONE;
    let now = get_block_timestamp();
    let start = now;
    let unlock_time: u64 = now + common::YEAR * 2;

    // blobert locks 2M LORDS for 2 years
    start_prank(CheatTarget::One(velords.contract_address), blobert);
    velords.manage_lock(lock_amount, unlock_time, blobert);

    assert_eq!(lords.balance_of(blobert), balance - lock_amount, "LORDS balance mismatch after locking");
    assert_eq!(velords_token.total_supply(), velords_token.balance_of(blobert), "total supply mismatch after locking");
    assert_approx(
        velords_token.balance_of(blobert),
        common::lock_balance(lock_amount, common::YEAR * 2),
        common::day_decline_of(lock_amount) * 7,
        "blobert's veLORDS balance mismatch after locking"
    );

    // move time forward by ~0.5y
    let now: u64 = start + common::YEAR / 2;
    let time_remaining: u64 = common::YEAR * 2 - common::YEAR / 2;
    start_warp(CheatTarget::All, now);

    assert_approx(
        velords_token.balance_of(blobert),
        common::lock_balance(lock_amount, time_remaining),
        common::day_decline_of(lock_amount) * 7,
        "blobert's veLORDS balance mismatch after 0.5y"
    );

    // move time forward to 1y till lock expiry
    let now: u64 = start + common::YEAR;
    let time_remaining: u64 = common::YEAR;
    start_warp(CheatTarget::All, now);

    assert_approx(
        velords_token.balance_of(blobert),
        common::lock_balance(lock_amount, time_remaining),
        common::day_decline_of(lock_amount) * 7,
        "blobert's veLORDS balance mismatch after 1y"
    );

    // move time 1w before expiry
    let now: u64 = start + common::YEAR * 2 - common::WEEK;
    let time_remaining: u64 = common::WEEK;
    start_warp(CheatTarget::All, now);

    assert_approx(
        velords_token.balance_of(blobert),
        common::lock_balance(lock_amount, time_remaining),
        common::day_decline_of(lock_amount) * 7,
        "blobert's veLORDS balance mismatch 1w before expiry"
    );


    // move time 1w after expiry
    let now: u64 = start + common::YEAR * 2 + common::WEEK;
    start_warp(CheatTarget::All, now);

    assert_eq!(velords_token.balance_of(blobert), 0, "blobert's veLORDS balance mismatch after expiry");
}

// test other public fns
// test withdrawal - interacts with reward pool

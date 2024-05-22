use lordship::interfaces::IERC20::{IERC20Dispatcher, IERC20DispatcherTrait};
use lordship::interfaces::IVE::{IVEDispatcher, IVEDispatcherTrait};
use snforge_std::{ContractClass, ContractClassTrait, CheatTarget, declare, start_prank, start_warp, stop_prank};
use starknet::{ContractAddress, get_block_timestamp, contract_address_const};

pub const ONE: u256 = 1000000000000000000; // 10**18
const LORDS_SUPPLY: u256 = 500_000_000 * ONE; // 500M LORDS

pub const TS: u64 = 1710000000; // global start timestamp in the test suite
pub const DAY: u64 = 86400;
pub const WEEK: u64 = 7 * DAY;
pub const YEAR: u64 = 365 * DAY;
const MAX_LOCK: u64 = 4 * YEAR;

pub fn lords_owner() -> ContractAddress {
    contract_address_const::<'lords owner'>()
}

pub fn dlords_owner() -> ContractAddress {
    contract_address_const::<'dlords owner'>()
}

pub fn velords_owner() -> ContractAddress {
    contract_address_const::<'velords owner'>()
}

pub fn blobert() -> ContractAddress {
    contract_address_const::<'blobert'>()
}

pub fn loaf() -> ContractAddress {
    contract_address_const::<'loaf'>()
}

pub fn badguy() -> ContractAddress {
    contract_address_const::<'badguy'>()
}

fn LORDS() -> ContractAddress {
    // Starknet mainnet LORDS token address
    contract_address_const::<0x124aeb495b947201f5fac96fd1138e326ad86195b98df6dec9009158a533b49>()
}

pub fn deploy_lords() -> ContractAddress {
    let cls = declare("erc20");

    let mut calldata: Array<felt252> = Default::default();
    let name: ByteArray = "Lords";
    let symbol: ByteArray = "LORDS";
    let supply: u256 = LORDS_SUPPLY.into();
    let owner: ContractAddress = lords_owner();
    name.serialize(ref calldata);
    symbol.serialize(ref calldata);
    supply.serialize(ref calldata);
    owner.serialize(ref calldata);

    cls.deploy_at(@calldata, LORDS()).expect('lords deploy failed')
}

pub fn deploy_dlords() -> ContractAddress {
    let cls = declare("dlords");
    let calldata: Array<felt252> = array![dlords_owner().into()];
    cls.deploy(@calldata).expect('dlords deploy failed')
}

pub fn deploy_velords() -> ContractAddress {
    let cls = declare("velords");
    let calldata: Array<felt252> = array![velords_owner().into()];
    cls.deploy(@calldata).expect('velords deploy failed')
}

pub fn deploy_reward_pool(velords: ContractAddress, dlords: ContractAddress) -> ContractAddress {
    let cls = declare("dlords_reward_pool");
    let calldata: Array<felt252> = array![velords.into(), dlords.into(), get_block_timestamp().into()];
    cls.deploy(@calldata).expect('reward pool deploy failed')
}

pub fn velords_setup() -> (IVEDispatcher, IERC20Dispatcher) {
    start_warp(CheatTarget::All, TS);

    let lords: ContractAddress = deploy_lords();
    let velords: ContractAddress = deploy_velords();
    let dlords: ContractAddress = deploy_dlords();
    let reward_pool: ContractAddress = deploy_reward_pool(velords, dlords);

    start_prank(CheatTarget::One(velords), velords_owner());
    IVEDispatcher { contract_address: velords }.set_reward_pool(reward_pool);
    stop_prank(CheatTarget::One(velords));

    (IVEDispatcher { contract_address: velords }, IERC20Dispatcher { contract_address: lords })
}

pub fn fund_lords(recipient: ContractAddress, amount: Option<u256>) {
    let default_amount: u256 = ONE * 10_000_000; // 10M LORDS
    let amount: u256 = amount.unwrap_or(default_amount);
    let lords: ContractAddress = LORDS();

    start_prank(CheatTarget::One(lords), lords_owner());
    IERC20Dispatcher { contract_address: lords }.transfer(recipient, amount);
    stop_prank(CheatTarget::One(lords));
}

pub fn setup_for_blobert(lords: ContractAddress, velords: ContractAddress) {
    // give blobert 10M LORDS
    let amount: u256 = ONE * 10_000_000; // 10M LORDS
    fund_lords(blobert(), Option::Some(amount));

    // blobert allows veLords contract to use its LORDS
    start_prank(CheatTarget::One(lords), blobert());
    IERC20Dispatcher { contract_address: lords }.approve(velords, amount);
    stop_prank(CheatTarget::One(lords));
}

pub fn floor_to_week(ts: u64) -> u64 {
    (ts / WEEK) * WEEK
}

pub fn assert_approx<T, impl TPartialOrd: PartialOrd<T>, impl TSub: Sub<T>, impl TCopy: Copy<T>, impl TDrop: Drop<T>>(
    a: T, b: T, tolerance: T, msg: ByteArray
) {
    if a >= b {
        assert!(a - b <= tolerance, "{msg}");
    } else {
        assert!(b - a <= tolerance, "{msg}");
    }
}

pub fn lock_balance(amount: u256, time_remaining: u64) -> u256 {
    (amount * time_remaining.into()) / MAX_LOCK.into()
}

pub fn day_decline_of(amount: u256) -> u256 {
    // calculates by how much the locked token
    // amount declines in a day
    (amount * DAY.into()) / MAX_LOCK.into()
}

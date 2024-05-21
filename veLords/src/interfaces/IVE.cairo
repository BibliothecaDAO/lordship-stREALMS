use lordship::velords::{Lock, Point};
use starknet::ContractAddress;

#[starknet::interface]
pub trait IVE<TContractState> {
    // TODO: docs

    //
    // getters
    //

    fn get_epoch_for(self: @TContractState, owner: ContractAddress) -> u64;
    fn get_lock_for(self: @TContractState, owner: ContractAddress) -> Lock;
    fn get_last_point(self: @TContractState, owner: ContractAddress) -> Point;
    fn get_point_for_at(self: @TContractState, owner: ContractAddress, epoch: u64) -> Point; // point history
    fn get_prior_votes(self: @TContractState, owner: ContractAddress, height: u64) -> u256;
    fn get_slope_change(self: @TContractState, owner: ContractAddress, ts: u64) -> i128;
    fn get_reward_pool(self: @TContractState) -> ContractAddress;
    fn find_epoch_by_timestamp(self: @TContractState, owner: ContractAddress, ts: u64) -> u64;
    fn balance_of_at(self: @TContractState, owner: ContractAddress, ts: u64) -> u256;
    fn total_supply_at(self: @TContractState, height: u64) -> u256;

    //
    // modifiers
    //

    fn manage_lock(ref self: TContractState, amount: u256, unlock_time: u64, owner: ContractAddress);
    fn checkpoint(ref self: TContractState);
    fn withdraw(ref self: TContractState) -> (u128, u128);
    fn set_reward_pool(ref self: TContractState, reward_pool: ContractAddress);
}

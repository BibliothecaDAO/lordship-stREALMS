use starknet::ContractAddress;
use starknet::account::Call;

#[starknet::interface]
pub trait IBurner<TContractState> {
    fn burn_lords(ref self: TContractState);
}

#[starknet::interface]
pub trait IBurnerAdmin<TContractState> {
    fn execute_calls(ref self: TContractState, calls: Array<Call>) -> Array<Span<felt252>>;
}

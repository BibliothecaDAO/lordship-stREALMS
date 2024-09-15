use starknet::ContractAddress;

#[starknet::interface]
pub trait IBurner<TContractState> {
    fn burn_lords(ref self: TContractState);
}

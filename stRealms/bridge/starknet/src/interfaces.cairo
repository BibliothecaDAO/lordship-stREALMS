use array::{SpanTrait};
use starknet::{ClassHash, ContractAddress, EthAddress};
use bridge::request::Request;

#[starknet::interface]
trait IBridge<T> {
    fn deposit_tokens(ref self: T, salt: felt252, owner_l1: EthAddress, token_ids: Span<u256>,);

    fn set_l1_bridge_address(ref self: T, address: EthAddress);
    fn set_l2_token_address(ref self: T, address: ContractAddress);

    fn get_l1_bridge_address(self: @T) -> EthAddress;
    fn get_l2_token_address(self: @T) -> ContractAddress;
}

#[starknet::interface]
trait IERC721MinterBurner<TState> {
    fn burn(ref self: TState, token_id: u256);
    fn safe_mint(
        ref self: TState, recipient: starknet::ContractAddress, token_id: u256, data: Span<felt252>,
    );
}

//////////////////////////
/// Events

#[derive(Drop, starknet::Event)]
struct DepositRequestInitiated {
    #[key]
    hash: u256,
    #[key]
    block_timestamp: u64,
    req_content: Request,
}


#[derive(Drop, starknet::Event)]
struct WithdrawRequestCompleted {
    #[key]
    hash: u256,
    #[key]
    block_timestamp: u64,
    req_content: Request
}

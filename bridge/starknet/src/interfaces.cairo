use array::{SpanTrait};
use starknet::{ClassHash, ContractAddress, EthAddress};
use realms::request::Request;

#[starknet::interface]
trait IBridge<T> {
    fn deposit_tokens(ref self: T, salt: felt252, owner_l1: EthAddress, token_ids: Span<u256>,);

    fn set_bridge_l1_addr(ref self: T, address: EthAddress);
    fn get_bridge_l1_addr(self: @T) -> EthAddress;
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

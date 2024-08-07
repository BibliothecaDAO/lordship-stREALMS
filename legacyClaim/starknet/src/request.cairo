/// Request to bridge reward

use starknet::{ContractAddress, EthAddress};
#[derive(Serde, Drop)]
struct Request {
    // Owner on Ethereum (for all the tokens in the request).
    owner_l1: EthAddress,
    // Owners on Starknet (for all the tokens in the request).
    owner_l2: ContractAddress,
    // Claim id
    claim_id: u16
}
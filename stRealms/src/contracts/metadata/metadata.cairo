/// Realms Metadata
#[starknet::interface]
trait IRealmMetadataEncoded<TState> {
    fn get_encoded_metadata(self: @TState, token_id: u16) -> felt252;
    fn get_decoded_metadata(self: @TState, token_id: u16) -> ByteArray;
}

#[starknet::contract]
mod RealmMetadata {
    use strealm::contracts::metadata::utils::make_json_and_base64_encode_metadata;

    use strealm::data::metadata::compressed_metadata;
    use super::IRealmMetadataEncoded;

    #[storage]
    struct Storage {}

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {}

    #[abi(embed_v0)]
    impl ERC721MetadataEncoded of IRealmMetadataEncoded<ContractState> {
        fn get_encoded_metadata(self: @ContractState, token_id: u16) -> felt252 {
            compressed_metadata(token_id.into())
        }

        fn get_decoded_metadata(self: @ContractState, token_id: u16) -> ByteArray {
            make_json_and_base64_encode_metadata(compressed_metadata(token_id.into()))
        }
    }
}

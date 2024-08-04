/// Realms Metadata
#[starknet::interface]
trait IRealmMetadataEncoded<TState> {
    fn get_encoded_metadata(self: @TState, token_id: u16) -> (felt252, felt252, felt252);
    fn get_decoded_metadata(self: @TState, token_id: u16) -> ByteArray;
}

#[starknet::interface]
trait IMetadataEncoded<TState> {
    fn data(self: @TState, token_id: u16) -> felt252;
}

#[starknet::contract]
mod RealmMetadata {
    use starknet::ClassHash;
    use strealm::contracts::metadata::utils::make_json_and_base64_encode_metadata;
    use strealm::data::metadata::compressed_name_and_attrs;
    use super::{
        IRealmMetadataEncoded, IMetadataEncodedLibraryDispatcher, IMetadataEncodedDispatcherTrait
    };

    #[storage]
    struct Storage {
        RealmMetadata_name_and_attrs: ClassHash,
        RealmMetadata_url_part_a: ClassHash,
        RealmMetadata_url_part_b: ClassHash
    }

    #[abi(embed_v0)]
    impl ERC721MetadataEncoded of IRealmMetadataEncoded<ContractState> {
        fn get_encoded_metadata(
            self: @ContractState, token_id: u16
        ) -> (felt252, felt252, felt252) {
            (
                IMetadataEncodedLibraryDispatcher {
                    class_hash: self.RealmMetadata_name_and_attrs.read()
                }
                    .data(token_id),
                IMetadataEncodedLibraryDispatcher {
                    class_hash: self.RealmMetadata_url_part_a.read()
                }
                    .data(token_id),
                IMetadataEncodedLibraryDispatcher {
                    class_hash: self.RealmMetadata_url_part_b.read()
                }
                    .data(token_id)
            )
        }
        fn get_decoded_metadata(self: @ContractState, token_id: u16) -> ByteArray {
            let (encoded_name_and_attrs, encoded_url_a, encoded_url_b) = self
                .get_encoded_metadata(token_id);
            make_json_and_base64_encode_metadata(
                encoded_name_and_attrs, (encoded_url_a, encoded_url_b)
            )
        }
    }

    #[constructor]
    fn constructor(
        ref self: ContractState,
        name_and_attrs_class_hash: ClassHash,
        url_part_a_class_hash: ClassHash,
        url_part_b_class_hash: ClassHash
    ) {
        self.RealmMetadata_name_and_attrs.write(name_and_attrs_class_hash);
        self.RealmMetadata_url_part_a.write(url_part_a_class_hash);
        self.RealmMetadata_url_part_b.write(url_part_b_class_hash);
    }
}


#[starknet::contract]
mod NameAndAttrsMetadata {
    use strealm::data::metadata::compressed_name_and_attrs;
    use super::IMetadataEncoded;

    #[storage]
    struct Storage {}


    #[abi(embed_v0)]
    impl NameAndAttrsMetadataEncoded of IMetadataEncoded<ContractState> {
        fn data(self: @ContractState, token_id: u16) -> felt252 {
            compressed_name_and_attrs(token_id.into())
        }
    }
}

#[starknet::contract]
mod URLPartAMetadata {
    use strealm::data::metadata::compressed_url_first;
    use super::IMetadataEncoded;

    #[storage]
    struct Storage {}

    #[abi(embed_v0)]
    impl URLPartAMetadataEncoded of IMetadataEncoded<ContractState> {
        fn data(self: @ContractState, token_id: u16) -> felt252 {
            compressed_url_first(token_id.into())
        }
    }
}


#[starknet::contract]
mod URLPartBMetadata {
    use strealm::data::metadata::compressed_url_second;
    use super::IMetadataEncoded;

    #[storage]
    struct Storage {}

    #[abi(embed_v0)]
    impl URLPartBMetadataEncoded of IMetadataEncoded<ContractState> {
        fn data(self: @ContractState, token_id: u16) -> felt252 {
            compressed_url_second(token_id.into())
        }
    }
}


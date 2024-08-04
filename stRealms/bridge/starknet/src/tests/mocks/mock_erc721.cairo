#[starknet::interface]
trait IERC721Minter<TContractState> {
    fn burn(ref self: TContractState, token_id: u256);
    fn mint(ref self: TContractState, recipient: starknet::ContractAddress, token_id: u256);
    fn safe_mint(
        ref self: TContractState,
        recipient: starknet::ContractAddress,
        token_id: u256,
        data: Span<felt252>
    );
}

#[starknet::contract]
mod ERC721Mock {
    use openzeppelin::introspection::src5::SRC5Component;
    use openzeppelin::token::erc721::{ERC721Component};
    use openzeppelin::token::erc721::{ERC721HooksEmptyImpl};
    use starknet::{ContractAddress, ClassHash};

    component!(path: ERC721Component, storage: erc721, event: ERC721Event);
    component!(path: SRC5Component, storage: src5, event: SRC5Event);

    // ERC721Mixin
    #[abi(embed_v0)]
    impl ERC721MixinImpl = ERC721Component::ERC721MixinImpl<ContractState>;
    impl ERC721InternalImpl = ERC721Component::InternalImpl<ContractState>;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        erc721: ERC721Component::Storage,
        #[substorage(v0)]
        src5: SRC5Component::Storage,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        ERC721Event: ERC721Component::Event,
        SRC5Event: SRC5Component::Event
    }


    #[abi(embed_v0)]
    impl ERC721MinterImpl of super::IERC721Minter<ContractState> {
        fn burn(ref self: ContractState, token_id: u256) {
            self.erc721.burn(token_id);
        }

        fn mint(ref self: ContractState, recipient: ContractAddress, token_id: u256,) {
            self.erc721.mint(recipient, token_id);
        }

        fn safe_mint(
            ref self: ContractState, recipient: ContractAddress, token_id: u256, data: Span<felt252>
        ) {
            self.erc721.mint(recipient, token_id);
        }
    }

    #[constructor]
    fn constructor(ref self: ContractState) {
        self.erc721.initializer("Realm Mock", "Realm Mock", "");
    }
}

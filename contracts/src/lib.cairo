
mod deps {
    mod erc721 {
        mod extensions;
    }
}

#[starknet::contract]
mod StRealm {
    use openzeppelin::access::ownable::OwnableComponent;
    use openzeppelin::introspection::src5::SRC5Component;
    use openzeppelin::token::erc721::{ERC721Component};
    use strealm::deps::erc721::extensions::ERC721VotesComponent::InternalTrait as ERC721VotesInternalTrait;
    use strealm::deps::erc721::extensions::ERC721VotesComponent;
    use openzeppelin::utils::cryptography::nonces::NoncesComponent;
    use openzeppelin::utils::cryptography::snip12::SNIP12Metadata;
    use starknet::ContractAddress;

    component!(path: ERC721Component, storage: erc721, event: ERC721Event);
    component!(path: SRC5Component, storage: src5, event: SRC5Event);
    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);

    component!(path: ERC721VotesComponent, storage: erc721_votes, event: ERC721VotesEvent);
    component!(path: NoncesComponent, storage: nonces, event: NoncesEvent);

    // ERC721Votes
    #[abi(embed_v0)]
    impl ERC721VotesComponentImpl =
        ERC721VotesComponent::ERC721VotesImpl<ContractState>; 

    // ERC721Mixin
    #[abi(embed_v0)]
    impl ERC721MixinImpl = ERC721Component::ERC721MixinImpl<ContractState>;
    
    // Nonces
    #[abi(embed_v0)]
    impl NoncesImpl = NoncesComponent::NoncesImpl<ContractState>;

    #[abi(embed_v0)]
    impl OwnableMixinImpl = OwnableComponent::OwnableMixinImpl<ContractState>;

    impl ERC721InternalImpl = ERC721Component::InternalImpl<ContractState>;
    impl OwnableInternalImpl = OwnableComponent::InternalImpl<ContractState>;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        erc721_votes: ERC721VotesComponent::Storage,
        #[substorage(v0)]
        erc721: ERC721Component::Storage,
        #[substorage(v0)]
        src5: SRC5Component::Storage,
        #[substorage(v0)]
        ownable: OwnableComponent::Storage,
        #[substorage(v0)]
        nonces: NoncesComponent::Storage
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        ERC721VotesEvent: ERC721VotesComponent::Event,
        #[flat]
        ERC721Event: ERC721Component::Event,
        #[flat]
        SRC5Event: SRC5Component::Event,
        #[flat]
        OwnableEvent: OwnableComponent::Event,
        #[flat]
        NoncesEvent: NoncesComponent::Event
    }


    /// Required for hash computation.
    impl SNIP12MetadataImpl of SNIP12Metadata {
        fn name() -> felt252 {
            'stRealm'
        }
        fn version() -> felt252 {
            '1'
        }
    }


    //
    // Hooks ERC721VotesHooks
    //

    impl ERC721VotesHooksImpl<
        TContractState,
        impl ERC721Votes: ERC721VotesComponent::HasComponent<TContractState>,
        impl HasComponent: ERC721Component::HasComponent<TContractState>,
        +SRC5Component::HasComponent<TContractState>,
        +NoncesComponent::HasComponent<TContractState>,
        +Drop<TContractState>,
    > of ERC721Component::ERC721HooksTrait<TContractState> {
        fn before_update(
            ref self: ERC721Component::ComponentState<TContractState>,
            to: ContractAddress,
            token_id: u256,
            auth: ContractAddress
        ) {
            let mut erc721_votes_component = get_dep_component_mut!(ref self, ERC721Votes);
            erc721_votes_component.transfer_voting_units(self.owner_of(token_id), to, 1);
        }

        fn after_update(
            ref self: ERC721Component::ComponentState<TContractState>,
            to: ContractAddress,
            token_id: u256,
            auth: ContractAddress
        ) {
            
        }
    }


    #[constructor]
    fn constructor(ref self: ContractState, owner: ContractAddress) {
        self.erc721.initializer("stRealm", "stREALM", "");
        self.ownable.initializer(owner);
    }
}



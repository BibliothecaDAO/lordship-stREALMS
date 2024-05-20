const MINTER_ROLE: felt252 = selector!("MINTER_ROLE");

#[starknet::contract]
mod StRealmMock {
    use openzeppelin::access::accesscontrol::AccessControlComponent;
    use openzeppelin::access::accesscontrol::DEFAULT_ADMIN_ROLE;
    use openzeppelin::governance::utils::interfaces::votes::IVotes;
    use openzeppelin::introspection::src5::SRC5Component;
    use openzeppelin::token::erc721::{ERC721Component};
    use openzeppelin::token::erc721::{ERC721HooksEmptyImpl};

    use starknet::{ContractAddress, ClassHash};
    use strealm::components::strealm::StRealmComponent;
    use super::{MINTER_ROLE};


    component!(path: ERC721Component, storage: erc721, event: ERC721Event);
    component!(path: SRC5Component, storage: src5, event: SRC5Event);
    component!(path: AccessControlComponent, storage: access_control, event: AccessControlEvent);
    component!(path: StRealmComponent, storage: strealm, event: StRealmEvent);

    // ERC721Mixin
    #[abi(embed_v0)]
    impl ERC721MixinImpl = ERC721Component::ERC721MixinImpl<ContractState>;

    // StRealm
    #[abi(embed_v0)]
    impl StRealmComponentImpl = StRealmComponent::StRealmImpl<ContractState>;

    #[abi(embed_v0)]
    impl AccessControlImpl =
        AccessControlComponent::AccessControlImpl<ContractState>;

    impl ERC721InternalImpl = ERC721Component::InternalImpl<ContractState>;
    impl AccessControlInternalImpl = AccessControlComponent::InternalImpl<ContractState>;
    impl StRealmInternalImpl = StRealmComponent::InternalImpl<ContractState>;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        erc721: ERC721Component::Storage,
        #[substorage(v0)]
        src5: SRC5Component::Storage,
        #[substorage(v0)]
        access_control: AccessControlComponent::Storage,
        #[substorage(v0)]
        strealm: StRealmComponent::Storage
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        ERC721Event: ERC721Component::Event,
        SRC5Event: SRC5Component::Event,
        AccessControlEvent: AccessControlComponent::Event,
        StRealmEvent: StRealmComponent::Event
    }


    #[generate_trait]
    #[abi(per_item)]
    impl ERC721MinterImpl of ERC721MinterTrait {
        #[external(v0)]
        fn safe_mint(
            ref self: ContractState,
            recipient: ContractAddress,
            token_id: u256,
            data: Span<felt252>,
        ) {
            self.access_control.assert_only_role(MINTER_ROLE);
            self.erc721._safe_mint(recipient, token_id, data);
        }
    }

    #[constructor]
    fn constructor(
        ref self: ContractState,
        default_admin: ContractAddress,
        minter: ContractAddress,
        flow_rate: u256,
        reward_token: ContractAddress,
        reward_payer: ContractAddress
    ) {
        self.erc721.initializer("Staked Realm Mock", "stREALMMOCK", "");
        self.strealm.initializer(:flow_rate, :reward_token, :reward_payer);

        self.access_control.initializer();
        self.access_control._grant_role(DEFAULT_ADMIN_ROLE, default_admin);
        self.access_control._grant_role(MINTER_ROLE, minter);
    }
}

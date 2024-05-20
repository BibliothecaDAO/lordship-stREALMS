/// The goal of this contract is create a way to allow realm nft holders to get 
/// streamed {x} amount of $lords once they wrap their realms token to obtain vRealms and 
/// they delegate

/// Streams are maintained per address.
/// Whenever a vRealm is sent to any address and the recipient has unclaimed lords, 
/// all unclaimed lords that have been accrued up until that point are automatically 
/// transferred to the recipient and the stream is reset so that the recipient's new vrealms 
/// balance is used for calculating reward 

/// the Flow struct simply maintains the details of the current flow i.e the flow rate of lords (per second)
/// as well as when that flow rate gets expired. A flow rate gets expired when a new one is added. 
/// This means we can change the stream flow rate and when it is changed, everyone's current stream ends 
/// and they only start using the new flow rate when they have claimed their current stream reward

const MINTER_ROLE: felt252 = selector!("MINTER_ROLE");
const UPGRADER_ROLE: felt252 = selector!("UPGRADER_ROLE");

#[starknet::interface]
trait IERC721Minter<TState> {
    fn safe_mint(
        ref self: TState, recipient: starknet::ContractAddress, token_id: u256, data: Span<felt252>,
    );
}


#[starknet::contract]
mod Lordship {
    use openzeppelin::access::accesscontrol::AccessControlComponent;
    use openzeppelin::access::accesscontrol::DEFAULT_ADMIN_ROLE;
    use openzeppelin::governance::utils::interfaces::votes::IVotes;
    use openzeppelin::introspection::src5::SRC5Component;
    use openzeppelin::token::erc721::{ERC721Component};
    use openzeppelin::upgrades::UpgradeableComponent;
    use openzeppelin::upgrades::interface::IUpgradeable;
    use openzeppelin::utils::cryptography::nonces::NoncesComponent;
    use openzeppelin::utils::cryptography::snip12::SNIP12Metadata;

    use starknet::{ContractAddress, ClassHash};
    use strealm::components::erc721::extensions::ERC721VotesComponent::InternalTrait as ERC721VotesInternalTrait;
    use strealm::components::erc721::extensions::ERC721VotesComponent;
    use strealm::components::strealm::StRealmComponent::InternalTrait as StRealmInternalTrait;
    use strealm::components::strealm::StRealmComponent;
    use super::{IERC721Minter};
    use super::{MINTER_ROLE, UPGRADER_ROLE};

    component!(path: ERC721Component, storage: erc721, event: ERC721Event);
    component!(path: SRC5Component, storage: src5, event: SRC5Event);
    component!(path: AccessControlComponent, storage: access_control, event: AccessControlEvent);
    component!(path: UpgradeableComponent, storage: upgradeable, event: UpgradeableEvent);

    component!(path: ERC721VotesComponent, storage: erc721_votes, event: ERC721VotesEvent);
    component!(path: NoncesComponent, storage: nonces, event: NoncesEvent);
    component!(path: StRealmComponent, storage: strealm, event: StRealmEvent);

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

    // StRealm
    #[abi(embed_v0)]
    impl StRealmComponentImpl = StRealmComponent::StRealmImpl<ContractState>;

    #[abi(embed_v0)]
    impl AccessControlImpl =
        AccessControlComponent::AccessControlImpl<ContractState>;


    impl ERC721InternalImpl = ERC721Component::InternalImpl<ContractState>;
    impl AccessControlInternalImpl = AccessControlComponent::InternalImpl<ContractState>;
    impl UpgradeableInternalImpl = UpgradeableComponent::InternalImpl<ContractState>;
    impl StRealmInternalImpl = StRealmComponent::InternalImpl<ContractState>;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        erc721_votes: ERC721VotesComponent::Storage,
        #[substorage(v0)]
        erc721: ERC721Component::Storage,
        #[substorage(v0)]
        src5: SRC5Component::Storage,
        #[substorage(v0)]
        access_control: AccessControlComponent::Storage,
        #[substorage(v0)]
        upgradeable: UpgradeableComponent::Storage,
        #[substorage(v0)]
        nonces: NoncesComponent::Storage,
        #[substorage(v0)]
        strealm: StRealmComponent::Storage
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
        AccessControlEvent: AccessControlComponent::Event,
        #[flat]
        UpgradeableEvent: UpgradeableComponent::Event,
        #[flat]
        NoncesEvent: NoncesComponent::Event,
        #[flat]
        StRealmEvent: StRealmComponent::Event
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
    // Hooks ERC721Hooks
    //

    impl ERC721HooksImpl<
        TContractState,
        impl StRealm: StRealmComponent::HasComponent<TContractState>,
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
            let owner_before_transfer: ContractAddress = self._owner_of(token_id);
            let owner_after_transfer: ContractAddress = to;

            // updated streamed reward balance for both sender and receiver
            let mut strealm_component = get_dep_component_mut!(ref self, StRealm);
            strealm_component._update_stream_balance(owner_before_transfer);
            strealm_component._update_stream_balance(owner_after_transfer);

            // transfer voting units 
            let mut erc721_votes_component = get_dep_component_mut!(ref self, ERC721Votes);
            erc721_votes_component.transfer_voting_units(owner_before_transfer, to, 1);
        }

        fn after_update(
            ref self: ERC721Component::ComponentState<TContractState>,
            to: ContractAddress,
            token_id: u256,
            auth: ContractAddress
        ) {}
    }


    //
    // Hooks ERC721VotesHooks
    //

    impl ERC721VotesHooksImpl<
        TContractState,
        impl StRealm: StRealmComponent::HasComponent<TContractState>,
        impl HasComponent: ERC721VotesComponent::HasComponent<TContractState>,
        +ERC721Component::HasComponent<TContractState>,
        +SRC5Component::HasComponent<TContractState>,
        +NoncesComponent::HasComponent<TContractState>,
        +Drop<TContractState>,
    > of ERC721VotesComponent::ERC721VotesHooksTrait<TContractState> {
        fn before_delegate(
            ref self: ERC721VotesComponent::ComponentState<TContractState>,
            account: ContractAddress,
            delegatee: ContractAddress
        ) {
            let mut strealm_component = get_dep_component_mut!(ref self, StRealm);
            if delegatee.is_zero() {
                strealm_component._update_stream_balance(account);
                strealm_component._end_stream(account);
            } else {
                if self.delegates(account).is_zero() {
                    // no current delegates
                    strealm_component._reset_stream(account);
                }
            }
        }

        fn after_delegate(
            ref self: ERC721VotesComponent::ComponentState<TContractState>,
            account: ContractAddress,
            delegatee: ContractAddress
        ) {}
    }


    #[abi(embed_v0)]
    impl UpgradeableImpl of IUpgradeable<ContractState> {
        fn upgrade(ref self: ContractState, new_class_hash: ClassHash) {
            self.access_control.assert_only_role(UPGRADER_ROLE);
            self.upgradeable._upgrade(new_class_hash);
        }
    }


    #[abi(embed_v0)]
    impl ERC721MinterImpl of IERC721Minter<ContractState> {
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
        upgrader: ContractAddress,
        flow_rate: u256,
        reward_token: ContractAddress,
        reward_payer: ContractAddress
    ) {
        self.erc721.initializer("Staked Realm", "stREALM", "");
        self.strealm.initializer(:flow_rate, :reward_token, :reward_payer);

        self.access_control.initializer();
        self.access_control._grant_role(DEFAULT_ADMIN_ROLE, default_admin);
        self.access_control._grant_role(MINTER_ROLE, minter);
        self.access_control._grant_role(UPGRADER_ROLE, upgrader);
    }
}

use openzeppelin::token::erc721::interface::{IERC721Dispatcher};
use starknet::ContractAddress;

#[starknet::interface]
trait IERC721Wrapper<TState> {
    // Wrapper
    fn deposit_for(ref self: TState, account: ContractAddress, token_ids: Span<u256>) -> bool;
    fn withdraw_to(ref self: TState, account: ContractAddress, token_ids: Span<u256>) -> bool;
    fn underlying(self: @TState) -> IERC721Dispatcher;

    // IERC721 Receiver
    fn on_erc721_received(
        ref self: TState,
        operator: ContractAddress,
        from: ContractAddress,
        token_id: u256,
        data: Span<felt252>
    ) -> felt252;

    fn onERC721Received(
        ref self: TState,
        operator: ContractAddress,
        from: ContractAddress,
        tokenId: u256,
        data: Span<felt252>
    ) -> felt252;
}


#[starknet::component]
mod ERC721WrapperComponent {
    use openzeppelin::token::erc721::ERC721Component;
    use openzeppelin::token::erc721::ERC721Component::ERC721Impl;
    use openzeppelin::token::erc721::ERC721Component::InternalTrait as ERC721InternalTraits;
    use openzeppelin::token::erc721::interface::{
        IERC721, IERC721Dispatcher, IERC721DispatcherTrait
    };
    use openzeppelin::token::erc721::interface::IERC721_RECEIVER_ID;
    use starknet::{ContractAddress, get_caller_address, get_contract_address};
    use openzeppelin::introspection::src5::SRC5Component;
    use openzeppelin::introspection::src5::SRC5Component::InternalTrait as SRC5InternalTrait;

    use super::IERC721Wrapper;


    #[storage]
    struct Storage {
        ERC721Wrapper_underlying: IERC721Dispatcher,
    }


    mod Errors {
        const UNSUPPORTED_TOKEN: felt252 = 'Wrapper: unsupported token';
        const INCORRECT_OWNER: felt252 = 'Wrapper: incorrect owner';
    }

    #[embeddable_as(ERC721WrapperImpl)]
    impl ERC721Wrapper<
        TContractState,
        +HasComponent<TContractState>,
        impl ERC721: ERC721Component::HasComponent<TContractState>,
        +ERC721Component::ERC721HooksTrait<TContractState>,
        +SRC5Component::HasComponent<TContractState>,
        +Drop<TContractState>
    > of IERC721Wrapper<ComponentState<TContractState>> {
        fn deposit_for(
            ref self: ComponentState<TContractState>,
            account: ContractAddress,
            mut token_ids: Span<u256>
        ) -> bool {
            let underlying = self.underlying();
            loop {
                match token_ids.pop_front() {
                    Option::Some(token_id) => {
                        underlying
                            .transfer_from(get_caller_address(), get_contract_address(), *token_id);

                        let mut erc721_component = get_dep_component_mut!(ref self, ERC721);
                        erc721_component._safe_mint(account, *token_id, array![].span());
                    },
                    Option::None => { break; }
                }
            };

            true
        }


        fn withdraw_to(
            ref self: ComponentState<TContractState>,
            account: ContractAddress,
            mut token_ids: Span<u256>
        ) -> bool {
            let underlying = self.underlying();
            loop {
                match token_ids.pop_front() {
                    Option::Some(token_id) => {
                        // Setting an "auth" arguments enables the `_isAuthorized` check which verifies that the token exists
                        // (from != 0). Therefore, it is not needed to verify that the return value is not 0 here.
                        let mut erc721_component = get_dep_component_mut!(ref self, ERC721);
                        erc721_component._update(Zeroable::zero(), *token_id, get_caller_address());

                        underlying
                            .transfer_from(get_contract_address(), get_caller_address(), *token_id);
                    },
                    Option::None => { break; }
                }
            };

            true
        }

        fn underlying(self: @ComponentState<TContractState>) -> IERC721Dispatcher {
            self.ERC721Wrapper_underlying.read()
        }


        /// Called whenever the implementing contract receives `token_id` through
        /// a safe transfer. This function must return `IERC721_RECEIVER_ID`
        /// to confirm the token transfer.
        fn on_erc721_received(
            ref self: ComponentState<TContractState>,
            operator: ContractAddress,
            from: ContractAddress,
            token_id: u256,
            data: Span<felt252>
        ) -> felt252 {
            self._on_erc721_received(from, token_id);
            IERC721_RECEIVER_ID
        }


        fn onERC721Received(
            ref self: ComponentState<TContractState>,
            operator: ContractAddress,
            from: ContractAddress,
            tokenId: u256,
            data: Span<felt252>
        ) -> felt252 {
            self._on_erc721_received(from, tokenId);
            IERC721_RECEIVER_ID
        }
    }


    //
    // Internal
    //

    #[generate_trait]
    impl InternalImpl<
        TContractState,
        +HasComponent<TContractState>,
        impl ERC721: ERC721Component::HasComponent<TContractState>,
        impl SRC5: SRC5Component::HasComponent<TContractState>,
        +ERC721Component::ERC721HooksTrait<TContractState>,
        +Drop<TContractState>,
    > of InternalTrait<TContractState> {
        /// This should be used inside the contract's constructor.
        fn initializer(ref self: ComponentState<TContractState>, underlying: ContractAddress) {
            // set the underlying token address
            self.ERC721Wrapper_underlying.write(IERC721Dispatcher { contract_address: underlying });

            /// register the IERC721Receiver interface ID.
            let mut src5_component = get_dep_component_mut!(ref self, SRC5);
            src5_component.register_interface(IERC721_RECEIVER_ID);
        }

        /// @dev Mint a wrapped token to cover any underlyingToken that would have been transferred by mistake. Internal
        /// function that can be exposed with access control if desired.
        ///
        fn recover(
            ref self: ComponentState<TContractState>, account: ContractAddress, token_id: u256
        ) -> u256 {
            let owner = self.underlying().owner_of(token_id);
            assert(owner == get_caller_address(), Errors::INCORRECT_OWNER);

            let mut erc721_component = get_dep_component_mut!(ref self, ERC721);
            erc721_component._safe_mint(account, token_id, array![].span());

            return token_id;
        }


        fn _on_erc721_received(
            ref self: ComponentState<TContractState>, from: ContractAddress, token_id: u256
        ) {
            assert(
                self.underlying().contract_address == get_caller_address(),
                Errors::UNSUPPORTED_TOKEN
            );

            let mut erc721_component = get_dep_component_mut!(ref self, ERC721);
            erc721_component._safe_mint(from, token_id, array![].span());
        }
    }
}

#[starknet::contract]
mod bridge {
    use core::starknet::SyscallResultTrait;
    use starknet::{ClassHash, ContractAddress, EthAddress};
    use openzeppelin::access::ownable::OwnableComponent;
    use openzeppelin::token::erc721::interface::{ERC721ABIDispatcher, ERC721ABIDispatcherTrait};
    use openzeppelin::upgrades::UpgradeableComponent;
    use openzeppelin::upgrades::interface::IUpgradeable;

    use realms::interfaces::{
        IBridge, IERC721MinterBurnerDispatcher, IERC721MinterBurnerDispatcherTrait
    };

    // events
    use realms::interfaces::{DepositRequestInitiated, WithdrawRequestCompleted};
    use realms::request::{Request, compute_request_hash};

    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);
    component!(path: UpgradeableComponent, storage: upgradeable, event: UpgradeableEvent);

    #[abi(embed_v0)]
    impl OwnableTwoStepMixinImpl =
        OwnableComponent::OwnableTwoStepMixinImpl<ContractState>;

    impl OwnableInternalImpl = OwnableComponent::InternalImpl<ContractState>;
    impl UpgradeableInternalImpl = UpgradeableComponent::InternalImpl<ContractState>;

    #[storage]
    struct Storage {
        bridge_l1_address: EthAddress,
        realms_l2_address: ContractAddress,
        #[substorage(v0)]
        upgradeable: UpgradeableComponent::Storage,
        #[substorage(v0)]
        ownable: OwnableComponent::Storage,
    }

    #[constructor]
    fn constructor(
        ref self: ContractState, bridge_admin: ContractAddress, bridge_l1_address: EthAddress,
    ) {
        self.ownable.initializer(bridge_admin);
        self.bridge_l1_address.write(bridge_l1_address);
    }


    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        DepositRequestInitiated: DepositRequestInitiated,
        WithdrawRequestCompleted: WithdrawRequestCompleted,
        #[flat]
        UpgradeableEvent: UpgradeableComponent::Event,
        #[flat]
        OwnableEvent: OwnableComponent::Event,
    }


    /// Process message from L1 to receive realm token.
    ///
    /// # Arguments
    ///
    /// `from_address` - L1 sender address, must be Realms L1 Bridge.
    /// `req` - The request containing tokens to bridge.
    ///
    /// TODO: isn't better to receive a raw Span<felt252>
    /// to be more flexible? And the first felt25 being the header
    /// defines how the deserialization takes place?
    #[l1_handler]
    fn withdraw_auto_from_l1(ref self: ContractState, from_address: felt252, req: Request) {
        // ensure only the l1 bridge contract can cause this function to be called
        assert(self.bridge_l1_address.read().into() == from_address, 'Invalid L1 msg sender');

        let mut token_ids = req.ids;
        loop {
            match token_ids.pop_front() {
                Option::Some(token_id) => {
                    IERC721MinterBurnerDispatcher {
                        contract_address: self.realms_l2_address.read()
                    }
                        .safe_mint(req.owner_l2, *token_id, array![].span());
                },
                Option::None => { break; }
            }
        };

        self
            .emit(
                WithdrawRequestCompleted {
                    hash: req.hash,
                    block_timestamp: starknet::get_block_timestamp(),
                    req_content: req
                }
            );
    }


    #[abi(embed_v0)]
    impl UpgradeableImpl of IUpgradeable<ContractState> {
        fn upgrade(ref self: ContractState, new_class_hash: ClassHash) {
            self.ownable.assert_only_owner();
            self.upgradeable._upgrade(new_class_hash);
        }
    }


    #[abi(embed_v0)]
    impl BridgeImpl of IBridge<ContractState> {
        fn set_bridge_l1_addr(ref self: ContractState, address: EthAddress) {
            self.ownable.assert_only_owner();
            self.bridge_l1_address.write(address);
        }

        fn get_bridge_l1_addr(self: @ContractState) -> EthAddress {
            self.bridge_l1_address.read()
        }


        /// Deposits tokens to be bridged on the L1.
        ///
        /// # Arguments
        ///
        /// * `salt` - Randome salt to compute request hash.
        /// * `owner_l1` - Address of the owner on L1.
        /// * `tokens_ids` - Tokens to be bridged on L1.
        ///
        fn deposit_tokens(
            ref self: ContractState, salt: felt252, owner_l1: EthAddress, token_ids: Span<u256>,
        ) {

            assert!(token_ids.len() > 0, "no token id");
            assert!(owner_l1.is_non_zero(), "owner l1 address is zero");

            let from = starknet::get_caller_address();
            let mut ids = token_ids;
            let erc721_dispatcher = ERC721ABIDispatcher {
                contract_address: self.realms_l2_address.read()
            };
            loop {
                match ids.pop_front() {
                    Option::Some(token_id) => {
                        // ensure caller has permission to spend token
                        _is_token_approved_or_owner(erc721_dispatcher, from, *token_id);

                        // burn token
                        IERC721MinterBurnerDispatcher {
                            contract_address: self.realms_l2_address.read()
                        }
                            .burn(*token_id);
                    },
                    Option::None => { break; }
                }
            };

            let req = Request {
                hash: compute_request_hash(
                    salt, self.realms_l2_address.read(), owner_l1, token_ids
                ),
                owner_l1,
                owner_l2: starknet::get_caller_address(),
                ids: token_ids,
            };

            let mut buf: Array<felt252> = array![];
            req.serialize(ref buf);

            starknet::send_message_to_l1_syscall(self.bridge_l1_address.read().into(), buf.span(),)
                .unwrap_syscall();

            self
                .emit(
                    DepositRequestInitiated {
                        hash: req.hash,
                        block_timestamp: starknet::info::get_block_timestamp(),
                        req_content: req
                    }
                );
        }
    }


    // *** INTERNALS ***

    /// Returns whether `spender` is allowed to manage `token_id`.
    ///
    /// Requirements:
    ///
    /// - `token_id` exists.
    fn _is_token_approved_or_owner(
        token_dispatcher: ERC721ABIDispatcher, spender: ContractAddress, token_id: u256
    ) -> bool {
        let owner = token_dispatcher.owner_of(token_id);
        let is_approved_for_all = token_dispatcher.is_approved_for_all(owner, spender);
        owner == spender
            || is_approved_for_all
            || spender == token_dispatcher.get_approved(token_id)
    }
}

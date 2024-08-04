#[starknet::contract]
mod bridge {
    use core::starknet::SyscallResultTrait;
    use starknet::{ClassHash, ContractAddress, EthAddress};
    use openzeppelin::access::ownable::OwnableComponent;
    use openzeppelin::token::erc721::interface::{ERC721ABIDispatcher, ERC721ABIDispatcherTrait};
    use openzeppelin::upgrades::UpgradeableComponent;
    use openzeppelin::upgrades::interface::IUpgradeable;

    use bridge::interfaces::{
        IBridge, IERC721MinterBurnerDispatcher, IERC721MinterBurnerDispatcherTrait
    };

    // events
    use bridge::interfaces::{DepositRequestInitiated, WithdrawRequestCompleted};
    use bridge::request::{Request, compute_request_hash};

    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);
    component!(path: UpgradeableComponent, storage: upgradeable, event: UpgradeableEvent);

    #[abi(embed_v0)]
    impl OwnableTwoStepMixinImpl =
        OwnableComponent::OwnableTwoStepMixinImpl<ContractState>;

    impl OwnableInternalImpl = OwnableComponent::InternalImpl<ContractState>;
    impl UpgradeableInternalImpl = UpgradeableComponent::InternalImpl<ContractState>;

    #[storage]
    struct Storage {
        l1_bridge_address: EthAddress,
        l2_token_address: ContractAddress,
        #[substorage(v0)]
        upgradeable: UpgradeableComponent::Storage,
        #[substorage(v0)]
        ownable: OwnableComponent::Storage,
    }

    #[constructor]
    fn constructor(
        ref self: ContractState,
        bridge_admin: ContractAddress,
        l1_bridge_address: EthAddress,
        l2_token_address: ContractAddress
    ) {
        self.ownable.initializer(bridge_admin);
        self.l1_bridge_address.write(l1_bridge_address);
        self.l2_token_address.write(l2_token_address);
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
    #[l1_handler]
    fn withdraw_auto_from_l1(ref self: ContractState, from_address: felt252, req: Request) {
        // ensure only the l1 bridge contract can cause this function to be called
        assert(
            self.l1_bridge_address.read().into() == from_address, 'Bridge: Caller not L1 Bridge'
        );

        let mut token_ids = req.ids;
        loop {
            match token_ids.pop_front() {
                Option::Some(token_id) => {
                    IERC721MinterBurnerDispatcher { contract_address: self.l2_token_address.read() }
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
            self.upgradeable.upgrade(new_class_hash);
        }
    }


    #[abi(embed_v0)]
    impl BridgeImpl of IBridge<ContractState> {
        fn set_l1_bridge_address(ref self: ContractState, address: EthAddress) {
            self.ownable.assert_only_owner();
            self.l1_bridge_address.write(address);
        }

        fn set_l2_token_address(ref self: ContractState, address: ContractAddress) {
            self.ownable.assert_only_owner();
            self.l2_token_address.write(address);
        }

        fn get_l1_bridge_address(self: @ContractState) -> EthAddress {
            self.l1_bridge_address.read()
        }

        fn get_l2_token_address(self: @ContractState) -> ContractAddress {
            self.l2_token_address.read()
        }


        /// Initiates a deposit request to be executed on L1.
        ///
        /// # Arguments
        ///
        /// * `salt` - Random salt to compute request hash.
        /// * `owner_l1` - Receiver on L1 Ethereum address.
        /// * `tokens_ids` - Tokens to be bridged to L1.
        /// 
        /// Note: the caller must have given this contract the necessary approval to spend
        ///       the tokens on L2. and the caller must be the token owner.
        ///         
        ///        we want only the owner of the token to be able to call this function
        ///        to prevent the following scenerio  
        ///              - user approves bridge
        ///              - attacker calls this function with the user's token id and 
        ///                 the attacker's l1 address
        ///              - user's token is burned
        ///              - attacker is the owner of the token on l1
        /// 
        ///         this is achieved by using transfer_from(caller, this, *token_id)
        ///         instead of transfer_from(owner, this, *token_id)
        /// 
        /// Note: we expect the nft to be set up in such a way that only this 
        ///       bridge contract is allowed to burn the token
        /// 
        fn deposit_tokens(
            ref self: ContractState, salt: felt252, owner_l1: EthAddress, token_ids: Span<u256>,
        ) {
            assert!(token_ids.len() > 0, "Bridge: no token id");
            assert!(owner_l1.is_non_zero(), "Bridge: owner l1 address is zero");

            let this = starknet::get_contract_address();
            let caller = starknet::get_caller_address();
            let l2_token = self.l2_token_address.read();
            let mut ids = token_ids;
            let erc721_dispatcher = ERC721ABIDispatcher { contract_address: l2_token };
            let erc721_burn_dispatcher = IERC721MinterBurnerDispatcher {
                contract_address: l2_token
            };
            loop {
                match ids.pop_front() {
                    Option::Some(token_id) => {
                        // transfer token to bridge contract 
                        erc721_dispatcher.transfer_from(caller, this, *token_id);

                        // burn token

                        // @note we expect the nft token to have permissions
                        //       set up in such a way that only the bridge 
                        //       is allowed to burn
                        erc721_burn_dispatcher.burn(*token_id);
                    },
                    Option::None => { break; }
                }
            };

            let req = Request {
                hash: compute_request_hash(salt, l2_token, owner_l1, token_ids),
                owner_l1,
                owner_l2: caller,
                ids: token_ids,
            };

            let mut buf: Array<felt252> = array![];
            req.serialize(ref buf);

            starknet::send_message_to_l1_syscall(self.l1_bridge_address.read().into(), buf.span(),)
                .unwrap_syscall();

            self
                .emit(
                    DepositRequestInitiated {
                        hash: req.hash,
                        block_timestamp: starknet::get_block_timestamp(),
                        req_content: req
                    }
                );
        }
    }
}

#[cfg(test)]
mod tests {
    use snforge_std::{
        cheatcodes::{events::EventFetcher, events::EventAssertions, l1_handler::L1HandlerTrait},
        declare, ContractClass, ContractClassTrait, start_prank, stop_prank, CheatTarget, L1Handler,
        get_class_hash, spy_events, SpyOn
    };

    use openzeppelin::access::ownable::interface::{
        IOwnableTwoStepDispatcher, IOwnableTwoStepDispatcherTrait
    };
    use openzeppelin::upgrades::interface::{IUpgradeableDispatcher, IUpgradeableDispatcherTrait};
    use openzeppelin::token::erc721::interface::{IERC721Dispatcher, IERC721DispatcherTrait};
    use bridge::{
        request::{Request, compute_request_hash},
        interfaces::{IBridgeDispatcher, IBridgeDispatcherTrait},
    };
    use bridge::bridge::bridge as bridge_contract;
    use bridge::tests::mocks::mock_erc721::{
        ERC721Mock as erc721_mock_contract, IERC721MinterDispatcher, IERC721MinterDispatcherTrait
    };
    use starknet::{ContractAddress, ClassHash, EthAddress};

    fn BRIDGE_ADMIN() -> ContractAddress {
        starknet::contract_address_const::<'BRIDGE_ADMIN'>()
    }

    fn ALICE() -> ContractAddress {
        starknet::contract_address_const::<'ALICE'>()
    }

    fn BOB() -> ContractAddress {
        starknet::contract_address_const::<'BOB'>()
    }

    fn ALICE_L1() -> EthAddress {
        EthAddress { address: 'ALICE_L1' }
    }

    fn BOB_L1() -> EthAddress {
        EthAddress { address: 'BOB_L1' }
    }

    fn BRIDGE_L1() -> EthAddress {
        EthAddress { address: 'BRIDGE_L1' }
    }


    fn TEST_ERC721() -> ContractAddress {
        let erc721_mock_class = declare("ERC721Mock").unwrap();
        let (addr, _) = erc721_mock_class.deploy(@array![]).unwrap();
        addr
    }

    fn BRIDGE() -> ContractAddress {
        let bridge_class = declare("bridge").unwrap();
        let l2_token = TEST_ERC721();

        let mut constructor_calldata = array![];

        BRIDGE_ADMIN().serialize(ref constructor_calldata);
        BRIDGE_L1().serialize(ref constructor_calldata);
        l2_token.serialize(ref constructor_calldata);
        let (addr, _) = bridge_class.deploy(@constructor_calldata).unwrap();

        let bridge_dispatcher = IBridgeDispatcher { contract_address: addr };
        assert_eq!(bridge_dispatcher.get_l1_bridge_address(), BRIDGE_L1(), "bad l1 bridge address");
        assert_eq!(bridge_dispatcher.get_l2_token_address(), l2_token, "bad l2 token address");
        addr
    }

    fn SALT() -> felt252 {
        'SALT'
    }

    #[test]
    fn deposit_token() {
        // deploy bridge
        let bridge_address = BRIDGE();
        let bridge_dispatcher = IBridgeDispatcher { contract_address: bridge_address };

        // mint tokens to Alice and Bob
        let erc721_mock = IERC721Dispatcher {
            contract_address: bridge_dispatcher.get_l2_token_address()
        };
        let erc721_mint_mock = IERC721MinterDispatcher {
            contract_address: bridge_dispatcher.get_l2_token_address()
        };
        erc721_mint_mock.mint(ALICE(), 1);
        erc721_mint_mock.mint(ALICE(), 2);
        erc721_mint_mock.mint(BOB(), 3);
        assert!(erc721_mock.owner_of(1) == ALICE(), "Wrong owner");
        assert!(erc721_mock.owner_of(2) == ALICE(), "Wrong owner");
        assert!(erc721_mock.owner_of(3) == BOB(), "Wrong owner");

        // alice approves the bridge to spend her tokens
        start_prank(CheatTarget::One(erc721_mock.contract_address), ALICE());
        let alice_tokens: Span<u256> = array![1, 2].span();
        erc721_mock.approve(bridge_address, *alice_tokens[0]);
        erc721_mock.approve(bridge_address, *alice_tokens[1]);
        stop_prank(CheatTarget::One(erc721_mock.contract_address));

        // alice deposits tokens to bridge
        let mut bridge_spy = spy_events(SpyOn::One(bridge_address));
        start_prank(CheatTarget::One(bridge_address), ALICE());
        bridge_dispatcher.deposit_tokens(SALT(), ALICE_L1(), alice_tokens);
        stop_prank(CheatTarget::One(bridge_address));

        // ensure alice's tokens were burned
        let err_msg = @'ERC721: invalid token ID';
        assert_eq!(
            err_msg,
            starknet::syscalls::call_contract_syscall(
                erc721_mock.contract_address, selector!("owner_of"), array![1, 0].span()
            )
                .unwrap_err()[0]
        );

        assert_eq!(
            err_msg,
            starknet::syscalls::call_contract_syscall(
                erc721_mock.contract_address, selector!("owner_of"), array![2, 0].span()
            )
                .unwrap_err()[0]
        );

        // ensure the correct event details were emitted
        let req_hash = compute_request_hash(
            SALT(), erc721_mock.contract_address, ALICE_L1(), alice_tokens
        );
        let req_content = Request {
            hash: req_hash, owner_l1: ALICE_L1(), owner_l2: ALICE(), ids: alice_tokens,
        };
        bridge_spy
            .assert_emitted(
                @array![
                    (
                        bridge_address,
                        bridge_contract::Event::DepositRequestInitiated(
                            bridge_contract::DepositRequestInitiated {
                                hash: req_hash,
                                block_timestamp: starknet::get_block_timestamp(),
                                req_content
                            }
                        )
                    )
                ]
            );
    }


    #[test]
    #[should_panic(expected: 'ERC721: unauthorized caller')]
    fn deposit_token_no_bridge_approval() {
        // deploy bridge
        let bridge_address = BRIDGE();
        let bridge_dispatcher = IBridgeDispatcher { contract_address: bridge_address };

        // mint tokens to Alice and Bob
        let erc721_mock = IERC721Dispatcher {
            contract_address: bridge_dispatcher.get_l2_token_address()
        };
        let erc721_mint_mock = IERC721MinterDispatcher {
            contract_address: bridge_dispatcher.get_l2_token_address()
        };
        erc721_mint_mock.mint(ALICE(), 1);
        erc721_mint_mock.mint(ALICE(), 2);
        erc721_mint_mock.mint(BOB(), 3);
        assert!(erc721_mock.owner_of(1) == ALICE(), "Wrong owner");
        assert!(erc721_mock.owner_of(2) == ALICE(), "Wrong owner");
        assert!(erc721_mock.owner_of(3) == BOB(), "Wrong owner");

        // alice approves the bridge to spend her tokens
        start_prank(CheatTarget::One(erc721_mock.contract_address), ALICE());
        let alice_tokens: Span<u256> = array![1, 2].span();
        stop_prank(CheatTarget::One(erc721_mock.contract_address));

        /// comment out approval of one token
        // erc721_mock.approve(bridge_address, *alice_tokens[0]);
        erc721_mock.approve(bridge_address, *alice_tokens[1]);

        // alice deposits tokens to bridge
        start_prank(CheatTarget::One(bridge_address), ALICE());
        bridge_dispatcher.deposit_tokens(SALT(), ALICE_L1(), alice_tokens);
        stop_prank(CheatTarget::One(bridge_address));
    }


    #[test]
    #[should_panic(expected: "Bridge: no token id")]
    fn deposit_token_no_token_id() {
        // deploy bridge
        let bridge_address = BRIDGE();
        let bridge_dispatcher = IBridgeDispatcher { contract_address: bridge_address };

        // mint tokens to Alice and Bob
        let erc721_mock = IERC721Dispatcher {
            contract_address: bridge_dispatcher.get_l2_token_address()
        };
        let erc721_mint_mock = IERC721MinterDispatcher {
            contract_address: bridge_dispatcher.get_l2_token_address()
        };
        erc721_mint_mock.mint(ALICE(), 1);
        erc721_mint_mock.mint(ALICE(), 2);
        erc721_mint_mock.mint(BOB(), 3);
        assert!(erc721_mock.owner_of(1) == ALICE(), "Wrong owner");
        assert!(erc721_mock.owner_of(2) == ALICE(), "Wrong owner");
        assert!(erc721_mock.owner_of(3) == BOB(), "Wrong owner");

        // alice approves the bridge to spend her tokens
        start_prank(CheatTarget::One(erc721_mock.contract_address), ALICE());
        let alice_tokens: Span<u256> = array![].span();

        // alice deposits tokens to bridge
        start_prank(CheatTarget::One(bridge_address), ALICE());
        bridge_dispatcher.deposit_tokens(SALT(), ALICE_L1(), alice_tokens);
        stop_prank(CheatTarget::One(bridge_address));
    }


    #[test]
    #[should_panic(expected: "Bridge: owner l1 address is zero")]
    fn deposit_token_zero_owner_l1() {
        // deploy bridge
        let bridge_address = BRIDGE();
        let bridge_dispatcher = IBridgeDispatcher { contract_address: bridge_address };

        // mint tokens to Alice and Bob
        let erc721_mock = IERC721Dispatcher {
            contract_address: bridge_dispatcher.get_l2_token_address()
        };
        let erc721_mint_mock = IERC721MinterDispatcher {
            contract_address: bridge_dispatcher.get_l2_token_address()
        };
        erc721_mint_mock.mint(ALICE(), 1);
        erc721_mint_mock.mint(ALICE(), 2);
        erc721_mint_mock.mint(BOB(), 3);
        assert!(erc721_mock.owner_of(1) == ALICE(), "Wrong owner");
        assert!(erc721_mock.owner_of(2) == ALICE(), "Wrong owner");
        assert!(erc721_mock.owner_of(3) == BOB(), "Wrong owner");

        // alice approves the bridge to spend her tokens
        start_prank(CheatTarget::One(erc721_mock.contract_address), ALICE());
        let alice_tokens: Span<u256> = array![1, 2].span();
        erc721_mock.approve(bridge_address, *alice_tokens[0]);
        erc721_mock.approve(bridge_address, *alice_tokens[1]);

        // alice deposits tokens to bridge
        start_prank(CheatTarget::One(bridge_address), ALICE());
        bridge_dispatcher.deposit_tokens(SALT(), Zeroable::zero(), alice_tokens);
        stop_prank(CheatTarget::One(bridge_address));
    }


    #[test]
    #[should_panic(expected: 'ERC721: invalid sender')]
    fn deposit_token_caller_not_owner() {
        // deploy bridge
        let bridge_address = BRIDGE();
        let bridge_dispatcher = IBridgeDispatcher { contract_address: bridge_address };

        // mint tokens to Alice and Bob
        let erc721_mock = IERC721Dispatcher {
            contract_address: bridge_dispatcher.get_l2_token_address()
        };
        let erc721_mint_mock = IERC721MinterDispatcher {
            contract_address: bridge_dispatcher.get_l2_token_address()
        };
        erc721_mint_mock.mint(ALICE(), 1);
        erc721_mint_mock.mint(ALICE(), 2);
        erc721_mint_mock.mint(BOB(), 3);
        assert!(erc721_mock.owner_of(1) == ALICE(), "Wrong owner");
        assert!(erc721_mock.owner_of(2) == ALICE(), "Wrong owner");
        assert!(erc721_mock.owner_of(3) == BOB(), "Wrong owner");

        // alice approves the bridge to spend her tokens
        start_prank(CheatTarget::One(erc721_mock.contract_address), ALICE());
        let alice_tokens: Span<u256> = array![1, 2].span();
        erc721_mock.approve(bridge_address, *alice_tokens[0]);
        erc721_mock.approve(bridge_address, *alice_tokens[1]);

        // alice deposits tokens to bridge
        start_prank(CheatTarget::One(bridge_address), BOB());
        bridge_dispatcher.deposit_tokens(SALT(), BOB_L1(), alice_tokens);
        stop_prank(CheatTarget::One(bridge_address));
    }


    #[test]
    fn withdraw_token() {
        let bridge_address = BRIDGE();
        let bridge_dispatcher = IBridgeDispatcher { contract_address: bridge_address };
        let alice_token_ids_from_l1 = array![1_u256, 2_u256].span();
        let mut req = Request {
            hash: 0x12345, owner_l1: ALICE_L1(), owner_l2: ALICE(), ids: alice_token_ids_from_l1
        };
        let mut buf = array![];
        req.serialize(ref buf);

        let mut l1_handler = L1Handler {
            contract_address: bridge_address,
            // selector: 0x03593216f3a8b22f4cf375e5486e3d13bfde9d0f26976d20ac6f653c73f7e507,
            function_selector: selector!("withdraw_auto_from_l1"),
            from_address: BRIDGE_L1().into(),
            payload: buf.span()
        };
        let mut bridge_spy = spy_events(SpyOn::One(bridge_address));
        l1_handler.execute().unwrap();

        // Deserialize the request and check some expected values.
        let mut sp = buf.span();
        let req = Serde::<Request>::deserialize(ref sp).unwrap();

        let erc721 = IERC721Dispatcher {
            contract_address: bridge_dispatcher.get_l2_token_address()
        };
        assert!(erc721.owner_of(1) == ALICE(), "Wrong owner after req (1)");
        assert!(erc721.owner_of(2) == ALICE(), "Wrong owner after req (2)");

        bridge_spy
            .assert_emitted(
                @array![
                    (
                        bridge_address,
                        bridge_contract::Event::WithdrawRequestCompleted(
                            bridge_contract::WithdrawRequestCompleted {
                                hash: req.hash,
                                block_timestamp: starknet::info::get_block_timestamp(),
                                req_content: req,
                            }
                        )
                    )
                ]
            );
    }


    #[test]
    fn withdraw_token_wrong_l1_bridge_address() {
        let bridge_address = BRIDGE();
        let alice_token_ids_from_l1 = array![1_u256, 2_u256].span();
        let mut req = Request {
            hash: 0x12345, owner_l1: ALICE_L1(), owner_l2: ALICE(), ids: alice_token_ids_from_l1
        };
        let mut buf = array![];
        req.serialize(ref buf);

        let mut l1_handler = L1Handler {
            contract_address: bridge_address,
            // selector: 0x03593216f3a8b22f4cf375e5486e3d13bfde9d0f26976d20ac6f653c73f7e507,
            function_selector: selector!("withdraw_auto_from_l1"),
            from_address: 'wrong_l1_bridge_address',
            payload: buf.span()
        };

        assert_eq!(@'Bridge: Caller not L1 Bridge', l1_handler.execute().unwrap_err().at(0));
    }


    #[test]
    fn upgrade_as_admin() {
        let bridge_address = BRIDGE();
        let bridge_class_hash = get_class_hash(bridge_address);
        let first_bridge_dispatcher = IBridgeDispatcher { contract_address: bridge_address };
        let new_bridge_class_hash = get_class_hash(first_bridge_dispatcher.get_l2_token_address());
        assert_ne!(bridge_class_hash, new_bridge_class_hash);

        start_prank(CheatTarget::One(bridge_address), BRIDGE_ADMIN());
        IUpgradeableDispatcher { contract_address: bridge_address }.upgrade(new_bridge_class_hash);
        stop_prank(CheatTarget::One(bridge_address));
        assert!(
            get_class_hash(bridge_address) == new_bridge_class_hash,
            "Incorrect class hash after upgrade"
        );
    }


    #[test]
    #[should_panic(expected: ('Caller is not the owner',))]
    fn upgrade_as_non_admin() {
        let bridge_address = BRIDGE();
        let bridge_class_hash = get_class_hash(bridge_address);
        let first_bridge_dispatcher = IBridgeDispatcher { contract_address: bridge_address };
        let new_bridge_class_hash = get_class_hash(first_bridge_dispatcher.get_l2_token_address());
        assert_ne!(bridge_class_hash, new_bridge_class_hash);

        start_prank(CheatTarget::One(bridge_address), ALICE());
        IUpgradeableDispatcher { contract_address: bridge_address }.upgrade(new_bridge_class_hash);
    }


    #[test]
    fn support_two_step_transfer_ownership() {
        let bridge_address = BRIDGE();
        let bridge_ownable_dispatcher = IOwnableTwoStepDispatcher {
            contract_address: bridge_address
        };

        start_prank(CheatTarget::One(bridge_address), BRIDGE_ADMIN());
        bridge_ownable_dispatcher.transfer_ownership(ALICE());
        stop_prank(CheatTarget::One(bridge_address));
        assert_eq!(bridge_ownable_dispatcher.owner(), BRIDGE_ADMIN(), "bad owner");
        assert_eq!(bridge_ownable_dispatcher.pending_owner(), ALICE(), "bad pending owner");

        start_prank(CheatTarget::One(bridge_address), ALICE());
        bridge_ownable_dispatcher.accept_ownership();
        stop_prank(CheatTarget::One(bridge_address));
        assert_eq!(bridge_ownable_dispatcher.owner(), ALICE(), "bad owner");
    }


    #[test]
    #[should_panic(expected: ('Caller is not the owner',))]
    fn support_two_step_transfer_ownership__caller_not_admin() {
        let bridge_address = BRIDGE();
        let bridge_ownable_dispatcher = IOwnableTwoStepDispatcher {
            contract_address: bridge_address
        };

        start_prank(CheatTarget::One(bridge_address), ALICE());
        bridge_ownable_dispatcher.transfer_ownership(ALICE());
    }

    #[test]
    fn set_l1_token_address__by_admin() {
        let bridge_address = BRIDGE();
        let bridge_dispatcher = IBridgeDispatcher { contract_address: bridge_address };
        start_prank(CheatTarget::One(bridge_address), BRIDGE_ADMIN());
        bridge_dispatcher.set_l2_token_address(ALICE());
        stop_prank(CheatTarget::One(bridge_address));
        assert_eq!(bridge_dispatcher.get_l2_token_address(), ALICE(), "bad l2 token address");
    }

    #[test]
    #[should_panic(expected: ('Caller is not the owner',))]
    fn set_l1_token_address__caller_not_admin() {
        let bridge_address = BRIDGE();
        let bridge_dispatcher = IBridgeDispatcher { contract_address: bridge_address };
        bridge_dispatcher.set_l2_token_address(ALICE());
    }

    #[test]
    fn set_l1_bridge_address__by_admin() {
        let bridge_address = BRIDGE();
        let bridge_dispatcher = IBridgeDispatcher { contract_address: bridge_address };
        start_prank(CheatTarget::One(bridge_address), BRIDGE_ADMIN());
        bridge_dispatcher.set_l1_bridge_address(ALICE_L1());
        stop_prank(CheatTarget::One(bridge_address));
        assert_eq!(bridge_dispatcher.get_l1_bridge_address(), ALICE_L1(), "bad l1 bridge address");
    }


    #[test]
    #[should_panic(expected: ('Caller is not the owner',))]
    fn set_l1_bridge_address__caller_not_admin() {
        let bridge_address = BRIDGE();
        let bridge_dispatcher = IBridgeDispatcher { contract_address: bridge_address };
        bridge_dispatcher.set_l1_bridge_address(ALICE_L1());
    }
}

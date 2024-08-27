#[cfg(test)]
mod tests {
    use core::array::ArrayTrait;
    use snforge_std::{
        cheatcodes::{events::EventFetcher, events::EventAssertions, l1_handler::L1HandlerTrait},
        declare, ContractClass, ContractClassTrait, start_prank, stop_prank, CheatTarget, L1Handler,
        get_class_hash, spy_events, SpyOn
    };

    use openzeppelin::access::ownable::interface::{
        IOwnableTwoStepDispatcher, IOwnableTwoStepDispatcherTrait
    };
    use openzeppelin::upgrades::interface::{IUpgradeableDispatcher, IUpgradeableDispatcherTrait};
    use openzeppelin::token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};
    use bridge::{bridge::{IBridgeDispatcher, IBridgeDispatcherTrait}, request::{Request},};
    use bridge::bridge::bridge as bridge_contract;
    use bridge::tests::mocks::mock_erc20::{
        ERC20Mock as erc20_mock_contract, IERC20MinterDispatcher, IERC20MinterDispatcherTrait
    };
    use starknet::{ContractAddress, ClassHash, EthAddress};
    use result::ResultTrait;

    fn BRIDGE_ADMIN() -> ContractAddress {
        starknet::contract_address_const::<'BRIDGE_ADMIN'>()
    }

    fn BRIDGE_REWARD_SPONSOR() -> ContractAddress {
        starknet::contract_address_const::<'BRIDGE_SPONSOR'>()
    }

    fn ALICE() -> ContractAddress {
        starknet::contract_address_const::<'ALICE'>()
    }

    fn BOB() -> ContractAddress {
        starknet::contract_address_const::<'BOB'>()
    }

    fn ALICE_L1() -> EthAddress {
        EthAddress { address: 0x8114e78965b7f7e52e35b2cfbe33973a4ef320cb }
    }

    fn BOB_L1() -> EthAddress {
        EthAddress { address: 0x31331ec182777b3e3cf127f4709a8aaa8f76e549 }
    }

    fn ALICE_CLAIM_ID() -> u16 {
        2
    }

    fn BOB_CLAIM_ID() -> u16 {
        14
    }

    fn ALICE_CLAIM_AMOUNT() -> u256 {
        0x55005F0C614480000
    }

    fn BOB_CLAIM_AMOUNT() -> u256 {
        0x7F808E9291E6C0000
    }


    fn BRIDGE_L1() -> EthAddress {
        EthAddress { address: 'BRIDGE_L1' }
    }


    fn TEST_ERC20() -> ContractAddress {
        let erc20_mock_class = declare("ERC20Mock").unwrap();
        let (addr, _) = erc20_mock_class.deploy(@array![]).unwrap();
        addr
    }

    fn BRIDGE() -> ContractAddress {
        let bridge_class = declare("bridge").unwrap();
        let reward_token = TEST_ERC20();

        let mut constructor_calldata = array![];

        BRIDGE_ADMIN().serialize(ref constructor_calldata);
        reward_token.serialize(ref constructor_calldata);
        BRIDGE_REWARD_SPONSOR().serialize(ref constructor_calldata);

        let (addr, _) = bridge_class.deploy(@constructor_calldata).unwrap();

        // set l1 bridge address
        let bridge_dispatcher = IBridgeDispatcher { contract_address: addr };
        start_prank(CheatTarget::One(addr), BRIDGE_ADMIN());
        bridge_dispatcher.set_l1_bridge_address(BRIDGE_L1());
        stop_prank(CheatTarget::One(addr));
        assert_eq!(bridge_dispatcher.get_l1_bridge_address(), BRIDGE_L1(), "bad l1 bridge address");

        // mint reward tokens to bridge sponsor
        let mint_amount = ALICE_CLAIM_AMOUNT() * 100000000;
        IERC20MinterDispatcher { contract_address: reward_token }
            .mint(BRIDGE_REWARD_SPONSOR(), mint_amount);

        // reward sponsor approves bridge to spend reward tokens
        start_prank(CheatTarget::One(reward_token), BRIDGE_REWARD_SPONSOR());
        IERC20Dispatcher { contract_address: reward_token }.approve(addr, mint_amount);
        stop_prank(CheatTarget::One(reward_token));

        addr
    }


    #[test]
    fn withdraw_reward() {
        let bridge_address = BRIDGE();
        let bridge_dispatcher = IBridgeDispatcher { contract_address: bridge_address };
        let mut req = Request {
            owner_l1: ALICE_L1(), owner_l2: ALICE(), claim_id: ALICE_CLAIM_ID(),
        };
        let erc20 = IERC20Dispatcher { contract_address: bridge_dispatcher.get_reward_token() };
        assert!(erc20.balance_of(ALICE()).is_zero(), "expected alice to have no balance");
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
        assert!(erc20.balance_of(ALICE()) == ALICE_CLAIM_AMOUNT(), "wrong alice claim amount");
        bridge_spy
            .assert_emitted(
                @array![
                    (
                        bridge_address,
                        bridge_contract::Event::ClaimRequestCompleted(
                            bridge_contract::ClaimRequestCompleted {
                                l1_address: req.owner_l1,
                                l2_address: req.owner_l2,
                                amount: ALICE_CLAIM_AMOUNT()
                            }
                        )
                    )
                ]
            );
    }

    #[test]
    fn withdraw_reward_claim_more_than_once() {
        let bridge_address = BRIDGE();
        let bridge_dispatcher = IBridgeDispatcher { contract_address: bridge_address };
        let mut req = Request {
            owner_l1: ALICE_L1(), owner_l2: ALICE(), claim_id: ALICE_CLAIM_ID(),
        };
        let erc20 = IERC20Dispatcher { contract_address: bridge_dispatcher.get_reward_token() };
        assert!(erc20.balance_of(ALICE()).is_zero(), "expected alice to have no balance");

        let mut buf = array![];
        req.serialize(ref buf);

        let mut l1_handler = L1Handler {
            contract_address: bridge_address,
            // selector: 0x03593216f3a8b22f4cf375e5486e3d13bfde9d0f26976d20ac6f653c73f7e507,
            function_selector: selector!("withdraw_auto_from_l1"),
            from_address: BRIDGE_L1().into(),
            payload: buf.span()
        };
        // execute twice
        l1_handler.clone().execute().unwrap();
        match l1_handler.execute() {
            Result::Ok(_) => { assert!(false, "expected error"); },
            Result::Err(e) => {
                let mut e = e;
                e.pop_front();
                let mut expected_err_arr = array![];
                let expected_err: ByteArray = "Bridge: l1 caller already claimed";
                expected_err.serialize(ref expected_err_arr);
                assert_eq!(e, expected_err_arr);
            }
        };
    }


    #[test]
    fn withdraw_reward_claim_not_owner() {
        let bridge_address = BRIDGE();
        let bridge_dispatcher = IBridgeDispatcher { contract_address: bridge_address };
        let mut req = Request {
            owner_l1: ALICE_L1(), owner_l2: ALICE(), // use bob's claim id
             claim_id: BOB_CLAIM_ID(),
        };
        let erc20 = IERC20Dispatcher { contract_address: bridge_dispatcher.get_reward_token() };
        assert!(erc20.balance_of(ALICE()).is_zero(), "expected alice to have no balance");

        let mut buf = array![];
        req.serialize(ref buf);

        let mut l1_handler = L1Handler {
            contract_address: bridge_address,
            // selector: 0x03593216f3a8b22f4cf375e5486e3d13bfde9d0f26976d20ac6f653c73f7e507,
            function_selector: selector!("withdraw_auto_from_l1"),
            from_address: BRIDGE_L1().into(),
            payload: buf.span()
        };
        match l1_handler.execute() {
            Result::Ok(_) => { assert!(false, "expected error"); },
            Result::Err(e) => {
                let mut e = e;
                e.pop_front();
                let mut expected_err_arr = array![];
                let expected_err: ByteArray = "Bridge: l1 caller not reward owner";
                expected_err.serialize(ref expected_err_arr);
                assert_eq!(e, expected_err_arr);
            }
        };
    }


    #[test]
    fn withdraw_reward_wrong_l1_bridge_address() {
        let bridge_address = BRIDGE();
        let mut req = Request {
            owner_l1: ALICE_L1(), owner_l2: ALICE(), claim_id: ALICE_CLAIM_ID(),
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
        let new_bridge_class_hash = get_class_hash(first_bridge_dispatcher.get_reward_token());
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
        let new_bridge_class_hash = get_class_hash(first_bridge_dispatcher.get_reward_token());
        assert_ne!(bridge_class_hash, new_bridge_class_hash);

        start_prank(CheatTarget::One(bridge_address), ALICE());
        IUpgradeableDispatcher { contract_address: bridge_address }.upgrade(new_bridge_class_hash);
    }


    #[test]
    fn support_transfer_ownership() {
        let bridge_address = BRIDGE();
        let bridge_ownable_dispatcher = IOwnableTwoStepDispatcher {
            contract_address: bridge_address
        };

        start_prank(CheatTarget::One(bridge_address), BRIDGE_ADMIN());
        bridge_ownable_dispatcher.transfer_ownership(ALICE());
        stop_prank(CheatTarget::One(bridge_address));
        assert_eq!(bridge_ownable_dispatcher.owner(), ALICE(), "bad owner");
    }


    #[test]
    #[should_panic(expected: ('Caller is not the owner',))]
    fn support_transfer_ownership__caller_not_admin() {
        let bridge_address = BRIDGE();
        let bridge_ownable_dispatcher = IOwnableTwoStepDispatcher {
            contract_address: bridge_address
        };

        start_prank(CheatTarget::One(bridge_address), ALICE());
        bridge_ownable_dispatcher.transfer_ownership(ALICE());
    }

    #[test]
    fn set_reward_token_address__by_admin() {
        let bridge_address = BRIDGE();
        let bridge_dispatcher = IBridgeDispatcher { contract_address: bridge_address };
        start_prank(CheatTarget::One(bridge_address), BRIDGE_ADMIN());
        bridge_dispatcher.set_reward_token(ALICE());
        stop_prank(CheatTarget::One(bridge_address));
        assert_eq!(bridge_dispatcher.get_reward_token(), ALICE(), "bad l2 reward token");
    }

    #[test]
    #[should_panic(expected: ('Caller is not the owner',))]
    fn set_reward_token_address__caller_not_admin() {
        let bridge_address = BRIDGE();
        let bridge_dispatcher = IBridgeDispatcher { contract_address: bridge_address };
        bridge_dispatcher.set_reward_token(ALICE());
    }

    #[test]
    fn set_reward_sponsor__by_admin() {
        let bridge_address = BRIDGE();
        let bridge_dispatcher = IBridgeDispatcher { contract_address: bridge_address };
        start_prank(CheatTarget::One(bridge_address), BRIDGE_ADMIN());
        bridge_dispatcher.set_reward_sponsor(ALICE());
        stop_prank(CheatTarget::One(bridge_address));
        assert_eq!(bridge_dispatcher.get_reward_sponsor(), ALICE(), "bad reward sponsor");
    }

    #[test]
    #[should_panic(expected: ('Caller is not the owner',))]
    fn set_reward_sponsor__caller_not_admin() {
        let bridge_address = BRIDGE();
        let bridge_dispatcher = IBridgeDispatcher { contract_address: bridge_address };
        bridge_dispatcher.set_reward_sponsor(ALICE());
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

use starknet::{ContractAddress, EthAddress};

#[starknet::interface]
trait IBridge<T> {
    fn set_l1_bridge_address(ref self: T, address: EthAddress);
    fn set_reward_token(ref self: T, address: ContractAddress);
    fn set_reward_sponsor(ref self: T, address: ContractAddress);

    fn get_l1_bridge_address(self: @T) -> EthAddress;
    fn get_reward_token(self: @T) -> ContractAddress;
    fn get_reward_sponsor(self: @T) -> ContractAddress;
}


#[starknet::contract]
mod bridge {
    use core::starknet::SyscallResultTrait;
    use starknet::{ClassHash, ContractAddress, EthAddress};
    use openzeppelin::access::ownable::OwnableComponent;
    use openzeppelin::token::erc20::interface::{ERC20ABIDispatcher, ERC20ABIDispatcherTrait};
    use openzeppelin::upgrades::UpgradeableComponent;
    use openzeppelin::upgrades::interface::IUpgradeable;

    use bridge::request::{Request};
    use bridge::claims::{claims_mapping};
    use bridge::bridge::IBridge;

    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);
    component!(path: UpgradeableComponent, storage: upgradeable, event: UpgradeableEvent);

    #[abi(embed_v0)]
    impl OwnableMixinImpl = OwnableComponent::OwnableMixinImpl<ContractState>;
    impl OwnableInternalImpl = OwnableComponent::InternalImpl<ContractState>;
    impl UpgradeableInternalImpl = UpgradeableComponent::InternalImpl<ContractState>;

    #[storage]
    struct Storage {
        claimed: LegacyMap<EthAddress, bool>,
        l1_bridge_address: EthAddress,
        reward_token: ContractAddress,
        reward_sponsor: ContractAddress,
        #[substorage(v0)]
        upgradeable: UpgradeableComponent::Storage,
        #[substorage(v0)]
        ownable: OwnableComponent::Storage,
    }

    #[constructor]
    fn constructor(
        ref self: ContractState,
        bridge_admin: ContractAddress,
        reward_token: ContractAddress,
        reward_sponsor: ContractAddress
    ) {
        self.ownable.initializer(bridge_admin);
        self.reward_token.write(reward_token);
        self.reward_sponsor.write(reward_sponsor);
    }


    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        ClaimRequestCompleted: ClaimRequestCompleted,
        #[flat]
        UpgradeableEvent: UpgradeableComponent::Event,
        #[flat]
        OwnableEvent: OwnableComponent::Event,
    }

    #[derive(Drop, starknet::Event)]
    struct ClaimRequestCompleted {
        #[key]
        l1_address: EthAddress,
        #[key]
        l2_address: ContractAddress,
        amount: u256
    }

    /// Process message from L1 to receive realm token.
    ///
    /// # Arguments
    ///
    /// `from_address` - L1 sender address, must be Realms L1 Bridge.
    /// `req` - reward collection request.
    ///
    #[l1_handler]
    fn withdraw_auto_from_l1(ref self: ContractState, from_address: felt252, req: Request) {
        // ensure only the l1 bridge contract can cause this function to be called
        assert(
            self.l1_bridge_address.read().into() == from_address, 'Bridge: Caller not L1 Bridge'
        );

        // ensure the recipient's l1 and l2 addresses are non zero
        assert(req.owner_l1.is_non_zero(), 'Bridge: zero l1 address');
        assert(req.owner_l2.is_non_zero(), 'Bridge: zero l2 address');

        // ensure the rightful l1 owner called this function
        let (claim_l1_owner, claim_amount) = claims_mapping(req.claim_id.into());
        assert!(req.owner_l1.into() == claim_l1_owner, "Bridge: l1 caller not reward owner");

        // ensure claim can't be done more than once
        assert!(self.claimed.read(req.owner_l1) == false, "Bridge: l1 caller already claimed");
        self.claimed.write(req.owner_l1, true);

        // transfer reward
        assert!(
            ERC20ABIDispatcher { contract_address: self.reward_token.read() }
                .transfer_from(self.reward_sponsor.read(), req.owner_l2, claim_amount.into()),
            "Bridge: reward transfer failed"
        );

        self
            .emit(
                ClaimRequestCompleted {
                    l1_address: req.owner_l1, l2_address: req.owner_l2, amount: claim_amount.into()
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

        fn set_reward_token(ref self: ContractState, address: ContractAddress) {
            self.ownable.assert_only_owner();
            self.reward_token.write(address);
        }

        fn set_reward_sponsor(ref self: ContractState, address: ContractAddress) {
            self.ownable.assert_only_owner();
            self.reward_sponsor.write(address);
        }

        fn get_l1_bridge_address(self: @ContractState) -> EthAddress {
            self.l1_bridge_address.read()
        }

        fn get_reward_token(self: @ContractState) -> ContractAddress {
            self.reward_token.read()
        }

        fn get_reward_sponsor(self: @ContractState) -> ContractAddress {
            self.reward_sponsor.read()
        }
    }
}

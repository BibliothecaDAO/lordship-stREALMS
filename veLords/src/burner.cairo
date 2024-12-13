// A simple contract that receives lords and allows anyone 
// to call the burn function to send it to the reward pool

// the contract is upgradeable so new functions can be added in the future

#[starknet::contract]
mod burner {
    use lordship::interfaces::IBurner::{IBurner, IBurnerAdmin};
    use lordship::interfaces::IERC20::{IERC20Dispatcher, IERC20DispatcherTrait};
    use lordship::interfaces::IRewardPool::{IRewardPoolDispatcher, IRewardPoolDispatcherTrait};
    use openzeppelin::access::ownable::OwnableComponent;
    use openzeppelin::account::utils::execute_calls;
    use openzeppelin::upgrades::UpgradeableComponent;
    use openzeppelin::upgrades::interface::IUpgradeable;
    use starknet::account::Call;

    use starknet::{ClassHash, ContractAddress, get_contract_address, contract_address_const};

    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);
    component!(path: UpgradeableComponent, storage: upgradeable, event: UpgradeableEvent);

    #[abi(embed_v0)]
    impl OwnableTwoStepImpl = OwnableComponent::OwnableTwoStepImpl<ContractState>;
    impl OwnableInternalImpl = OwnableComponent::InternalImpl<ContractState>;
    impl UpgradeableInternalImpl = UpgradeableComponent::InternalImpl<ContractState>;

    #[storage]
    struct Storage {
        // component storage
        #[substorage(v0)]
        ownable: OwnableComponent::Storage,
        #[substorage(v0)]
        upgradeable: UpgradeableComponent::Storage,
        reward_pool: IRewardPoolDispatcher
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        #[flat]
        OwnableEvent: OwnableComponent::Event,
        #[flat]
        UpgradeableEvent: UpgradeableComponent::Event
    }

    fn LORDS_TOKEN() -> IERC20Dispatcher {
        IERC20Dispatcher {
            contract_address: contract_address_const::<
                0x0124aeb495b947201f5fac96fd1138e326ad86195b98df6dec9009158a533b49
            >()
        }
    }


    #[constructor]
    fn constructor(ref self: ContractState, owner: ContractAddress, reward_pool: ContractAddress,) {
        self.ownable.initializer(owner);
        self.reward_pool.write(IRewardPoolDispatcher { contract_address: reward_pool });
    }

    #[abi(embed_v0)]
    impl UpgradeableImpl of IUpgradeable<ContractState> {
        fn upgrade(ref self: ContractState, new_class_hash: ClassHash) {
            self.ownable.assert_only_owner();
            self.upgradeable._upgrade(new_class_hash);
        }
    }

    #[abi(embed_v0)]
    impl IBurnerImpl of IBurner<ContractState> {
        fn burn_lords(ref self: ContractState) {
            let this: ContractAddress = get_contract_address();
            let lords_token = LORDS_TOKEN();
            let lords_balance = lords_token.balance_of(this);
            assert!(lords_balance > 0, "LORDS balance is zero");

            let reward_pool = self.reward_pool.read();
            lords_token.approve(reward_pool.contract_address, lords_balance);
            reward_pool.burn(lords_balance);
        }
    }

    #[abi(embed_v0)]
    impl IBurnerAdminImpl of IBurnerAdmin<ContractState> {
        fn execute_calls(ref self: ContractState, mut calls: Array<Call>) -> Array<Span<felt252>> {
            self.ownable.assert_only_owner();
            execute_calls(calls)
        }
    }
}

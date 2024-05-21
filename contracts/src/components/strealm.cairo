#[starknet::interface]
trait IStRealm<TState> {
    fn get_reward_token(self: @TState) -> starknet::ContractAddress;
    fn get_reward_payer(self: @TState) -> starknet::ContractAddress;
    fn get_stream(self: @TState, owner: starknet::ContractAddress) -> strealm_structs::Stream;
    fn get_flow(self: @TState, flow_id: u64) -> strealm_structs::Flow;
    fn get_latest_flow_id(self: @TState) -> u64;
    fn get_reward_balance(self: @TState) -> u256;
    fn get_reward_balance_for(self: @TState, owner: starknet::ContractAddress) -> u256;

    fn reward_claim(ref self: TState);
    fn update_flow_rate(ref self: TState, new_rate: u256);
    fn update_reward_payer(ref self: TState, new_payer_address: starknet::ContractAddress);
}


mod strealm_structs {
    use starknet::storage_access::StorePacking;

    #[derive(Copy, Drop, Serde, starknet::Store)]
    struct Flow {
        rate: u256, // flow rate per second
        end_at: u64
    }

    #[derive(Copy, Drop, Serde)]
    struct Stream {
        flow_id: u64,
        start_at: u64
    }


    const TWO_POW_64: u128 = 0x10000000000000000;
    const MASK_64: u128 = 0xffffffffffffffff;

    impl StreamStorePacking of StorePacking<Stream, u128> {
        fn pack(value: Stream) -> u128 {
            value.flow_id.into() + (value.start_at.into() * TWO_POW_64)
        }

        fn unpack(value: u128) -> Stream {
            let flow_id = value & MASK_64;
            let start_at = (value / TWO_POW_64);

            Stream { flow_id: flow_id.try_into().unwrap(), start_at: start_at.try_into().unwrap(), }
        }
    }
}


#[starknet::component]
mod StRealmComponent {
    use core::integer::BoundedInt;
    use openzeppelin::access::accesscontrol::AccessControlComponent::InternalTrait as AccessControlInternalTrait;
    use openzeppelin::access::accesscontrol::AccessControlComponent;
    use openzeppelin::access::accesscontrol::DEFAULT_ADMIN_ROLE;
    use openzeppelin::introspection::src5::SRC5Component::InternalTrait as SRC5InternalTrait;
    use openzeppelin::introspection::src5::SRC5Component;
    use openzeppelin::token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};
    use openzeppelin::token::erc721::ERC721Component::InternalTrait as ERC721InternalTraits;
    use openzeppelin::token::erc721::ERC721Component;
    use openzeppelin::token::erc721::interface::IERC721_RECEIVER_ID;
    use openzeppelin::token::erc721::interface::{
        IERC721, IERC721Dispatcher, IERC721DispatcherTrait
    };
    use starknet::{ContractAddress, Store};
    use super::strealm_structs::{Flow, Stream};


    #[storage]
    struct Storage {
        StRealm_reward_token: ContractAddress,
        StRealm_reward_payer: ContractAddress,
        StRealm_streams: LegacyMap<ContractAddress, Stream>,
        StRealm_flows: LegacyMap<u64, Flow>,
        StRealm_latest_flow_id: u64,
        StRealm_staker_reward_balance: LegacyMap<ContractAddress, u256>
    }


    mod Errors {
        const ZERO_REWARD_BALANCE: felt252 = 'StRealm: zero reward balance';
        const FAILED_TRANSFER: felt252 = 'StRealm: failed transfer';
    }

    #[event]
    #[derive(Drop, PartialEq, starknet::Event)]
    enum Event {
        FlowRateChanged: FlowRateChanged,
        RewardTokenUpdated: RewardTokenUpdated,
        RewardPayerUpdated: RewardPayerUpdated,
        RewardClaimed: RewardClaimed
    }

    #[derive(Drop, PartialEq, starknet::Event)]
    struct FlowRateChanged {
        #[key]
        id: u64,
        rate: u256
    }

    #[derive(Drop, PartialEq, starknet::Event)]
    struct RewardTokenUpdated {
        #[key]
        old_address: ContractAddress,
        new_address: ContractAddress,
    }

    #[derive(Drop, PartialEq, starknet::Event)]
    struct RewardPayerUpdated {
        #[key]
        old_address: ContractAddress,
        new_address: ContractAddress,
    }

    #[derive(Drop, PartialEq, starknet::Event)]
    struct RewardClaimed {
        #[key]
        recipient: ContractAddress,
        amount: u256
    }


    #[embeddable_as(StRealmImpl)]
    impl StRealm<
        TContractState,
        +HasComponent<TContractState>,
        impl ERC721: ERC721Component::HasComponent<TContractState>,
        impl AccessControl: AccessControlComponent::HasComponent<TContractState>,
        +ERC721Component::ERC721HooksTrait<TContractState>,
        +SRC5Component::HasComponent<TContractState>,
        +Drop<TContractState>
    > of super::IStRealm<ComponentState<TContractState>> {
        //
        // Immutables
        //
        fn get_stream(self: @ComponentState<TContractState>, owner: ContractAddress) -> Stream {
            self.StRealm_streams.read(owner)
        }

        fn get_flow(self: @ComponentState<TContractState>, flow_id: u64) -> Flow {
            self.StRealm_flows.read(flow_id)
        }

        fn get_latest_flow_id(self: @ComponentState<TContractState>) -> u64 {
            self.StRealm_latest_flow_id.read()
        }

        fn get_reward_balance(self: @ComponentState<TContractState>) -> u256 {
            let (balance, _) = self._reward_balance(starknet::get_caller_address());
            balance
        }

        fn get_reward_balance_for(
            self: @ComponentState<TContractState>, owner: ContractAddress
        ) -> u256 {
            let (balance, _) = self._reward_balance(owner);
            balance
        }

        fn get_reward_token(self: @ComponentState<TContractState>) -> ContractAddress {
            self.StRealm_reward_token.read()
        }

        fn get_reward_payer(self: @ComponentState<TContractState>) -> ContractAddress {
            self.StRealm_reward_payer.read()
        }


        //
        // Mutables
        //
        fn reward_claim(ref self: ComponentState<TContractState>) {
            self._reward_claim(starknet::get_caller_address())
        }

        fn update_flow_rate(ref self: ComponentState<TContractState>, new_rate: u256) {
            let accesscontrol_component = get_dep_component!(@self, AccessControl);
            accesscontrol_component.assert_only_role(DEFAULT_ADMIN_ROLE);

            self._update_flow_rate(new_rate);
        }

        fn update_reward_payer(
            ref self: ComponentState<TContractState>, new_payer_address: ContractAddress
        ) {
            let accesscontrol_component = get_dep_component!(@self, AccessControl);
            accesscontrol_component.assert_only_role(DEFAULT_ADMIN_ROLE);

            self._update_reward_payer(new_payer_address);
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
        fn initializer(
            ref self: ComponentState<TContractState>,
            flow_rate: u256,
            reward_token: ContractAddress,
            reward_payer: ContractAddress
        ) {
            self._update_flow_rate(flow_rate);
            self._update_reward_token(reward_token);
            self._update_reward_payer(reward_payer);
        }


        fn _update_flow_rate(ref self: ComponentState<TContractState>, new_flow_rate: u256) {
            self._end_latest_flow();
            self._start_new_flow(new_flow_rate);
        }

        fn _update_reward_token(
            ref self: ComponentState<TContractState>, new_reward_token_address: ContractAddress
        ) {
            self
                .emit(
                    RewardTokenUpdated {
                        old_address: self.StRealm_reward_token.read(),
                        new_address: new_reward_token_address
                    }
                );
            self.StRealm_reward_token.write(new_reward_token_address);
        }

        fn _update_reward_payer(
            ref self: ComponentState<TContractState>, new_reward_payer_address: ContractAddress
        ) {
            self
                .emit(
                    RewardPayerUpdated {
                        old_address: self.StRealm_reward_payer.read(),
                        new_address: new_reward_payer_address
                    }
                );
            self.StRealm_reward_payer.write(new_reward_payer_address);
        }


        fn _end_latest_flow(ref self: ComponentState<TContractState>) {
            let flow_id = self.StRealm_latest_flow_id.read();
            let mut flow: Flow = self.StRealm_flows.read(flow_id);
            flow.end_at = starknet::get_block_timestamp();
            self.StRealm_flows.write(flow_id, flow);
        }

        fn _start_new_flow(ref self: ComponentState<TContractState>, new_flow_rate: u256) {
            let new_flow_id = self.StRealm_latest_flow_id.read() + 1;
            self.StRealm_latest_flow_id.write(new_flow_id);

            let new_flow: Flow = Flow { rate: new_flow_rate, end_at: BoundedInt::max() };
            self.StRealm_flows.write(new_flow_id, new_flow);

            self.emit(FlowRateChanged { id: new_flow_id, rate: new_flow.rate });
        }


        fn _restart_stream(ref self: ComponentState<TContractState>, owner: ContractAddress) {
            let stream = Stream {
                start_at: starknet::get_block_timestamp(),
                flow_id: self.StRealm_latest_flow_id.read()
            };
            self.StRealm_streams.write(owner, stream);
        }

        fn _end_stream(ref self: ComponentState<TContractState>, owner: ContractAddress) {
            if owner.is_non_zero() {
                self.StRealm_streams.write(owner, Stream { flow_id: 0, start_at: 0 });
            }
        }

        fn _reward_balance(
            self: @ComponentState<TContractState>, owner: ContractAddress
        ) -> (u256, bool) {
            if owner.is_non_zero() {
                let staker_reward_balance = self.StRealm_staker_reward_balance.read(owner);
                let stream: Stream = self.StRealm_streams.read(owner);
                let owner_has_stream = stream.flow_id.is_non_zero()
                    && stream.start_at.is_non_zero();
                if owner_has_stream {
                    let flow: Flow = self.StRealm_flows.read(stream.flow_id);
                    let latest_flow_id: u64 = self.StRealm_latest_flow_id.read();

                    let stream_end_at = if latest_flow_id > stream.flow_id {
                        flow.end_at
                    } else {
                        starknet::get_block_timestamp()
                    };

                    let stream_duration = stream_end_at - stream.start_at;
                    let erc721_component = get_dep_component!(self, ERC721);

                    let num_staked_realms = erc721_component.balance_of(owner);
                    let streamed_amount = num_staked_realms * stream_duration.into() * flow.rate;

                    return (staker_reward_balance + streamed_amount, owner_has_stream);
                } else {
                    (staker_reward_balance, false)
                }
            } else {
                (0_u256, false)
            }
        }


        /// must be called before balance updates
        fn _update_stream_balance(
            ref self: ComponentState<TContractState>, owner: ContractAddress
        ) -> u256 {
            if owner.is_non_zero() {
                let (new_reward_balance, owner_has_stream) = self._reward_balance(owner);
                if owner_has_stream {
                    self.StRealm_staker_reward_balance.write(owner, new_reward_balance);
                    self._restart_stream(owner);
                }

                new_reward_balance
            } else {
                0_u256
            }
        }


        fn _reward_claim(ref self: ComponentState<TContractState>, owner: ContractAddress) {
            // get reward balance
            let owner_reward_balance = self._update_stream_balance(owner);
            assert(owner_reward_balance.is_non_zero(), Errors::ZERO_REWARD_BALANCE);

            // send reward
            assert(
                IERC20Dispatcher { contract_address: self.StRealm_reward_token.read() }
                    .transfer_from(self.StRealm_reward_payer.read(), owner, owner_reward_balance),
                Errors::FAILED_TRANSFER
            );
            self.emit(RewardClaimed { recipient: owner, amount: owner_reward_balance });

            // set balance to zero
            self.StRealm_staker_reward_balance.write(owner, 0);
        }
    }
}

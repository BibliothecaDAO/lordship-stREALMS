use openzeppelin::token::erc721::interface::{IERC721Dispatcher};
use starknet::ContractAddress;

use StRealmComponent::{Flow, Stream};
#[starknet::interface]
trait IStRealm<TState> {
    fn get_stream(self: @TState, owner: ContractAddress) -> Stream;
    fn get_flow(self: @TState, flow_id: u32) -> Flow;
    fn get_latest_flow_id(self: @TState) -> u32;

    fn claim(ref self: TState);
    fn update_flow_rate(ref self: TState, new_rate: u256);
    fn update_reward_token(ref self: TState, new_token_address: ContractAddress);
    fn update_reward_payer(ref self: TState, new_payer_address: ContractAddress);
}

#[starknet::component]
mod StRealmComponent {
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
    use openzeppelin::token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};
    use openzeppelin::access::accesscontrol::AccessControlComponent;
    use openzeppelin::access::accesscontrol::AccessControlComponent::InternalTrait as AccessControlInternalTrait;
    use openzeppelin::access::accesscontrol::DEFAULT_ADMIN_ROLE;


    use core::integer::BoundedInt;

    #[derive(Copy, Drop, Serde, starknet::Store)]
    struct Flow {
        rate: u256, // flow rate per second
        end_at: u64
    }

    #[derive(Copy, Drop, Serde, starknet::Store)]
    struct Stream {
        flow_id: u32,
        start_at: u64
    }

    #[storage]
    struct Storage {
        StRealm_reward_token: ContractAddress,
        StRealm_reward_payer: ContractAddress,
        StRealm_streams: LegacyMap<ContractAddress, Stream>,
        StRealm_flows: LegacyMap<u32, Flow>,
        StRealm_latest_flow_id: u32
    }


    mod Errors {
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
        id: u32,
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

        fn get_flow(self: @ComponentState<TContractState>, flow_id: u32) -> Flow {
            self.StRealm_flows.read(flow_id)
        }

        fn get_latest_flow_id(self: @ComponentState<TContractState>) -> u32 {
            self.StRealm_latest_flow_id.read()
        }


        //
        // Mutables
        //
        fn claim(ref self: ComponentState<TContractState>) {
            self._claim_stream(starknet::get_caller_address())
        }

        fn update_flow_rate(ref self: ComponentState<TContractState>, new_rate: u256) {
            let accesscontrol_component = get_dep_component!(@self, AccessControl);
            accesscontrol_component.assert_only_role(DEFAULT_ADMIN_ROLE);

            self._update_flow_rate(new_rate);
        }

        fn update_reward_token(
            ref self: ComponentState<TContractState>, new_token_address: ContractAddress
        ) {
            let accesscontrol_component = get_dep_component!(@self, AccessControl);
            accesscontrol_component.assert_only_role(DEFAULT_ADMIN_ROLE);

            self._update_reward_token(new_token_address);
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
            let new_flow: Flow = Flow { rate: new_flow_rate, end_at: BoundedInt::max() };
            self.StRealm_flows.write(new_flow_id, new_flow);

            self
                .emit(
                    FlowRateChanged {
                        id: new_flow_id,
                        rate: new_flow.rate
                    }
                );
        }


        fn _reset_stream(ref self: ComponentState<TContractState>, owner: ContractAddress) {
            let mut stream: Stream = self.StRealm_streams.read(owner);
            stream.start_at = starknet::get_block_timestamp();
            stream.flow_id = self.StRealm_latest_flow_id.read();
            self.StRealm_streams.write(owner, stream);
        }

        fn _end_stream(ref self: ComponentState<TContractState>, owner: ContractAddress) {
            if owner.is_non_zero() {
                let mut stream: Stream = self.StRealm_streams.read(owner);
                stream.start_at = 0;
                stream.flow_id = 0;
                self.StRealm_streams.write(owner, stream);
            }
        }


        fn _streamed_amount(
            ref self: ComponentState<TContractState>,
            token_amount: u256,
            stream_duration: u64,
            flow_rate: u256
        ) -> u256 {
            token_amount * stream_duration.into() * flow_rate
        }


        /// must be calld before balance updates
        fn _claim_stream(ref self: ComponentState<TContractState>, owner: ContractAddress) {
            if owner.is_non_zero() {
                let stream: Stream = self.StRealm_streams.read(owner);
                if stream.flow_id.is_non_zero() && stream.start_at.is_non_zero() {
                    let flow: Flow = self.StRealm_flows.read(stream.flow_id);
                    let latest_flow_id: u32 = self.StRealm_latest_flow_id.read();

                    let mut stream_end_at: u64 = starknet::get_block_timestamp();
                    if latest_flow_id > stream.flow_id {
                        stream_end_at = flow.end_at;
                    }

                    let stream_duration = stream_end_at - stream.start_at;
                    let erc721_component = get_dep_component!(@self, ERC721);

                    let streamed_amount = self
                        ._streamed_amount(
                            erc721_component.balance_of(owner), stream_duration, flow.rate
                        );

                    // send reward
                    if streamed_amount.is_non_zero() {
                        assert(
                            IERC20Dispatcher { contract_address: self.StRealm_reward_token.read() }
                                .transfer_from(
                                    self.StRealm_reward_payer.read(), owner, streamed_amount
                                ),
                            Errors::FAILED_TRANSFER
                        );
                        self.emit(RewardClaimed { recipient: owner, amount: streamed_amount });
                    }

                    // reset stream
                    self._reset_stream(owner);
                }
            }
        }
    }
}

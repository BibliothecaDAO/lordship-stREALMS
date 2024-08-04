use core::hash::HashStateExTrait;
use hash::{HashStateTrait, Hash};
use openzeppelin::utils::cryptography::snip12::{OffchainMessageHash, StructHash, SNIP12Metadata};
use poseidon::PoseidonTrait;
use starknet::ContractAddress;

/// # ERC721Votes Component
///
/// The ERC721Votes component tracks voting units from ERC721 balances, which are a measure of voting power that can be
/// transferred, and provides a system of vote delegation, where an account can delegate its voting units to a sort of
/// "representative" that will pool delegated voting units from different accounts and can then use it to vote in
/// decisions. In fact, voting units MUST be delegated in order to count as actual votes, and an account has to
/// delegate those votes to itself if it wishes to participate in decisions and does not have a trusted representative.
#[starknet::interface]
trait IERC721Votes<TState> {
    fn get_votes(self: @TState, account: ContractAddress) -> u256;
    fn get_past_votes(self: @TState, account: ContractAddress, timepoint: u64) -> u256;
    fn get_past_total_supply(self: @TState, timepoint: u64) -> u256;

    fn delegates(self: @TState, account: ContractAddress) -> ContractAddress;
    fn delegate(ref self: TState, delegatee: ContractAddress);
    fn delegate_by_sig(
        ref self: TState,
        delegator: ContractAddress,
        delegatee: ContractAddress,
        nonce: felt252,
        expiry: u64,
        signature: Array<felt252>
    );
}


#[starknet::component]
mod ERC721VotesComponent {
    use openzeppelin::account::dual_account::{DualCaseAccount, DualCaseAccountABI};
    use openzeppelin::governance::utils::interfaces::IVotes;
    use openzeppelin::introspection::src5::SRC5Component;
    use openzeppelin::token::erc721::ERC721Component::ERC721Impl;
    use openzeppelin::token::erc721::ERC721Component;
    use openzeppelin::token::erc721::interface::IERC721;
    use openzeppelin::utils::nonces::NoncesComponent::InternalTrait as NoncesInternalTrait;
    use openzeppelin::utils::nonces::NoncesComponent;
    use openzeppelin::utils::structs::checkpoint::{Checkpoint, Trace, TraceTrait};
    use starknet::ContractAddress;
    use super::{Delegation, OffchainMessageHash, SNIP12Metadata};

    #[storage]
    struct Storage {
        ERC721Votes_delegatee: LegacyMap<ContractAddress, ContractAddress>,
        ERC721Votes_delegate_checkpoints: LegacyMap<ContractAddress, Trace>,
        ERC721Votes_total_checkpoints: Trace
    }

    #[event]
    #[derive(Drop, PartialEq, starknet::Event)]
    enum Event {
        DelegateChanged: DelegateChanged,
        DelegateVotesChanged: DelegateVotesChanged,
    }

    /// Emitted when `delegator` delegates their votes from `from_delegate` to `to_delegate`.
    #[derive(Drop, PartialEq, starknet::Event)]
    struct DelegateChanged {
        #[key]
        delegator: ContractAddress,
        #[key]
        from_delegate: ContractAddress,
        #[key]
        to_delegate: ContractAddress
    }

    /// Emitted when `delegate` votes are updated from `previous_votes` to `new_votes`.
    #[derive(Drop, PartialEq, starknet::Event)]
    struct DelegateVotesChanged {
        #[key]
        delegate: ContractAddress,
        previous_votes: u256,
        new_votes: u256
    }

    mod Errors {
        const FUTURE_LOOKUP: felt252 = 'Votes: future Lookup';
        const EXPIRED_SIGNATURE: felt252 = 'Votes: expired signature';
        const INVALID_SIGNATURE: felt252 = 'Votes: invalid signature';
    }

    //
    // Hooks
    //

    trait ERC721VotesHooksTrait<TContractState> {
        fn before_delegate(
            ref self: ComponentState<TContractState>,
            account: ContractAddress,
            delegatee: ContractAddress
        );


        fn after_delegate(
            ref self: ComponentState<TContractState>,
            account: ContractAddress,
            delegatee: ContractAddress
        );
    }

    //
    // External
    //

    #[embeddable_as(ERC721VotesImpl)]
    impl ERC721Votes<
        TContractState,
        +HasComponent<TContractState>,
        +ERC721Component::HasComponent<TContractState>,
        +ERC721Component::ERC721HooksTrait<TContractState>,
        +ERC721VotesHooksTrait<TContractState>,
        +SRC5Component::HasComponent<TContractState>,
        impl Nonces: NoncesComponent::HasComponent<TContractState>,
        +SNIP12Metadata,
        +Drop<TContractState>
    > of IVotes<ComponentState<TContractState>> {
        /// Returns the current amount of votes that `account` has.
        fn get_votes(self: @ComponentState<TContractState>, account: ContractAddress) -> u256 {
            self.ERC721Votes_delegate_checkpoints.read(account).latest()
        }

        /// Returns the amount of votes that `account` had at a specific moment in the past.
        ///
        /// Requirements:
        ///
        /// - `timepoint` must be in the past.
        fn get_past_votes(
            self: @ComponentState<TContractState>, account: ContractAddress, timepoint: u64
        ) -> u256 {
            let current_timepoint = starknet::get_block_timestamp();
            assert(timepoint < current_timepoint, Errors::FUTURE_LOOKUP);

            self.ERC721Votes_delegate_checkpoints.read(account).upper_lookup_recent(timepoint)
        }

        /// Returns the total supply of votes available at a specific moment in the past.
        ///
        /// Requirements:
        ///
        /// - `timepoint` must be in the past.
        ///
        /// NOTE: This value is the sum of all available votes, which is not necessarily the sum of all delegated votes.
        /// Votes that have not been delegated are still part of total supply, even though they would not participate in a
        /// vote.
        fn get_past_total_supply(self: @ComponentState<TContractState>, timepoint: u64) -> u256 {
            let current_timepoint = starknet::get_block_timestamp();
            assert(timepoint < current_timepoint, Errors::FUTURE_LOOKUP);

            self.ERC721Votes_total_checkpoints.read().upper_lookup_recent(timepoint)
        }

        /// Returns the delegate that `account` has chosen.
        fn delegates(
            self: @ComponentState<TContractState>, account: ContractAddress
        ) -> ContractAddress {
            self.ERC721Votes_delegatee.read(account)
        }

        /// Delegates votes from the sender to `delegatee`.
        ///
        /// Emits a `DelegateChanged` event.
        /// May emit one or two `DelegateVotesChanged` events.
        fn delegate(ref self: ComponentState<TContractState>, delegatee: ContractAddress) {
            let sender = starknet::get_caller_address();
            self._delegate(sender, delegatee);
        }

        /// Delegates votes from the sender to `delegatee` through a SNIP12 message signature validation.
        ///
        /// Requirements:
        ///
        /// - `expiry` must not be in the past.
        /// - `nonce` must match the account's current nonce.
        /// - `delegator` must implement `SRC6::is_valid_signature`.
        /// - `signature` should be valid for the message hash.
        ///
        /// Emits a `DelegateChanged` event.
        /// May emit one or two `DelegateVotesChanged` events.
        fn delegate_by_sig(
            ref self: ComponentState<TContractState>,
            delegator: ContractAddress,
            delegatee: ContractAddress,
            nonce: felt252,
            expiry: u64,
            signature: Array<felt252>
        ) {
            assert(starknet::get_block_timestamp() <= expiry, Errors::EXPIRED_SIGNATURE);

            // Check and increase nonce.
            let mut nonces_component = get_dep_component_mut!(ref self, Nonces);
            nonces_component.use_checked_nonce(delegator, nonce);

            // Build hash for calling `is_valid_signature`.
            let delegation = Delegation { delegatee, nonce, expiry };
            let hash = delegation.get_message_hash(delegator);

            let is_valid_signature_felt = DualCaseAccount { contract_address: delegator }
                .is_valid_signature(hash, signature);

            // Check either 'VALID' or True for backwards compatibility.
            let is_valid_signature = is_valid_signature_felt == starknet::VALIDATED
                || is_valid_signature_felt == 1;

            assert(is_valid_signature, Errors::INVALID_SIGNATURE);

            // Delegate votes.
            self._delegate(delegator, delegatee);
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
        +SRC5Component::HasComponent<TContractState>,
        +ERC721Component::ERC721HooksTrait<TContractState>,
        impl Hooks: ERC721VotesHooksTrait<TContractState>,
        +NoncesComponent::HasComponent<TContractState>,
        +SNIP12Metadata,
        +Drop<TContractState>,
    > of InternalTrait<TContractState> {
        /// Returns the current total supply of votes.
        fn get_total_supply(self: @ComponentState<TContractState>) -> u256 {
            self.ERC721Votes_total_checkpoints.read().latest()
        }

        /// Delegates all of `account`'s voting units to `delegatee`.
        ///
        /// Emits a `DelegateChanged` event.
        /// May emit one or two `DelegateVotesChanged` events.
        fn _delegate(
            ref self: ComponentState<TContractState>,
            account: ContractAddress,
            delegatee: ContractAddress
        ) {
            Hooks::before_delegate(ref self, account, delegatee);

            let from_delegate = self.delegates(account);
            self.ERC721Votes_delegatee.write(account, delegatee);

            self
                .emit(
                    DelegateChanged { delegator: account, from_delegate, to_delegate: delegatee }
                );
            self.move_delegate_votes(from_delegate, delegatee, self.get_voting_units(account));

            Hooks::after_delegate(ref self, account, delegatee);
        }

        /// Moves delegated votes from one delegate to another.
        ///
        /// May emit one or two `DelegateVotesChanged` events.
        fn move_delegate_votes(
            ref self: ComponentState<TContractState>,
            from: ContractAddress,
            to: ContractAddress,
            amount: u256
        ) {
            let zero_address = Zeroable::zero();
            let block_timestamp = starknet::get_block_timestamp();
            if (from != to && amount > 0) {
                if (from != zero_address) {
                    let mut trace = self.ERC721Votes_delegate_checkpoints.read(from);
                    let (previous_votes, new_votes) = trace
                        .push(block_timestamp, trace.latest() - amount);
                    self.emit(DelegateVotesChanged { delegate: from, previous_votes, new_votes });
                }
                if (to != zero_address) {
                    let mut trace = self.ERC721Votes_delegate_checkpoints.read(to);
                    let (previous_votes, new_votes) = trace
                        .push(block_timestamp, trace.latest() + amount);
                    self.emit(DelegateVotesChanged { delegate: to, previous_votes, new_votes });
                }
            }
        }

        /// Transfers, mints, or burns voting units.
        ///
        /// To register a mint, `from` should be zero. To register a burn, `to`
        /// should be zero. Total supply of voting units will be adjusted with mints and burns.
        ///
        /// May emit one or two `DelegateVotesChanged` events.
        fn transfer_voting_units(
            ref self: ComponentState<TContractState>,
            from: ContractAddress,
            to: ContractAddress,
            amount: u256
        ) {
            let zero_address = Zeroable::zero();
            let block_timestamp = starknet::get_block_timestamp();
            if (from == zero_address) {
                let mut trace = self.ERC721Votes_total_checkpoints.read();
                trace.push(block_timestamp, trace.latest() + amount);
            }
            if (to == zero_address) {
                let mut trace = self.ERC721Votes_total_checkpoints.read();
                trace.push(block_timestamp, trace.latest() - amount);
            }
            self.move_delegate_votes(self.delegates(from), self.delegates(to), amount);
        }

        /// Returns the voting units of an `account`.
        fn get_voting_units(
            self: @ComponentState<TContractState>, account: ContractAddress
        ) -> u256 {
            let mut erc721_component = get_dep_component!(self, ERC721);
            erc721_component.balance_of(account)
        }
    }
}

/// An empty implementation of the ERC721Votes hooks to be used in basic ERC721Votes preset contracts.
impl ERC721VotesHooksEmptyImpl<
    TContractState
> of ERC721VotesComponent::ERC721VotesHooksTrait<TContractState> {
    fn before_delegate(
        ref self: ERC721VotesComponent::ComponentState<TContractState>,
        account: ContractAddress,
        delegatee: ContractAddress
    ) {}


    fn after_delegate(
        ref self: ERC721VotesComponent::ComponentState<TContractState>,
        account: ContractAddress,
        delegatee: ContractAddress
    ) {}
}


//
// Offchain message hash generation helpers.
//

// sn_keccak("\"Delegation\"(\"delegatee\":\"ContractAddress\",\"nonce\":\"felt\",\"expiry\":\"u128\")")
//
// Since there's no u64 type in SNIP-12, we use u128 for `expiry` in the type hash generation.
const DELEGATION_TYPE_HASH: felt252 =
    0x241244ac7acec849adc6df9848262c651eb035a3add56e7f6c7bcda6649e837;

#[derive(Copy, Drop, Hash)]
struct Delegation {
    delegatee: ContractAddress,
    nonce: felt252,
    expiry: u64
}

impl StructHashImpl of StructHash<Delegation> {
    fn hash_struct(self: @Delegation) -> felt252 {
        let hash_state = PoseidonTrait::new();
        hash_state.update_with(DELEGATION_TYPE_HASH).update_with(*self).finalize()
    }
}

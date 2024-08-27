#[starknet::interface]
trait IERC20Minter<TContractState> {
    fn burn(ref self: TContractState, account: starknet::ContractAddress, amount: u256);
    fn mint(ref self: TContractState, recipient: starknet::ContractAddress, amount: u256);
}

#[starknet::contract]
mod ERC20Mock {
    use openzeppelin::introspection::src5::SRC5Component;
    use openzeppelin::token::erc20::{ERC20Component};
    use openzeppelin::token::erc20::{ERC20HooksEmptyImpl};
    use starknet::{ContractAddress, ClassHash};

    component!(path: ERC20Component, storage: erc20, event: ERC20Event);
    component!(path: SRC5Component, storage: src5, event: SRC5Event);

    // ERC20Mixin
    #[abi(embed_v0)]
    impl ERC20MixinImpl = ERC20Component::ERC20MixinImpl<ContractState>;
    impl ERC20InternalImpl = ERC20Component::InternalImpl<ContractState>;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        erc20: ERC20Component::Storage,
        #[substorage(v0)]
        src5: SRC5Component::Storage,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        ERC20Event: ERC20Component::Event,
        SRC5Event: SRC5Component::Event
    }


    #[abi(embed_v0)]
    impl ERC20MinterImpl of super::IERC20Minter<ContractState> {
        fn burn(ref self: ContractState, account: ContractAddress, amount: u256) {
            self.erc20.burn(account, amount);
        }

        fn mint(ref self: ContractState, recipient: ContractAddress, amount: u256,) {
            self.erc20.mint(recipient, amount);
        }
    }

    #[constructor]
    fn constructor(ref self: ContractState) {
        self.erc20.initializer("Lords Mock", "LMOCK");
    }
}

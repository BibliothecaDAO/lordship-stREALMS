# Only .env file is loaded by foundry, and we can't specify a file.
# TODO: need a better way to force config arg is given...!
# CLEAN_CONFIG:=$(shell rm .env)
# COPY_CONFIG:=$(shell cp $(config) .env)

include .env
export $(shell sed 's/=.*//' .env)

bold := $(shell tput bold)
sgr0 := $(shell tput sgr0)

# TODO: for upgrades, check how to force proxy arg.

# Bridge deploy impl + proxy.
bridge_l1_deploy:
	forge script --broadcast  --rpc-url ${ETH_RPC_URL} script/Bridge.s.sol:Deploy -vvvvvvvv

bridge_deposit:
	forge script --broadcast  --rpc-url ${ETH_RPC_URL} script/Bridge.s.sol:Deposit

# ERC721MintFree l1 contract
erc721_deploy:
	forge script --broadcast  --rpc-url ${ETH_RPC_URL} script/ERC721.s.sol:Deploy


# ERC721MintFree mint
erc721_mint:
	forge script --broadcast  --rpc-url ${ETH_RPC_URL} script/ERC721.s.sol:Mint




# # Bridge upgrade.
# bridge_upgrade:
# 	@printf "$(bold)Ensure you don't forget the proxy argument:\n"
# 	@echo "usage: make bridge_upgrade config=.yourconfig.env proxy=0x1234"
# 	@printf "$(sgr0)\n"
# 	export BRIDGE_L1_PROXY_ADDRESS=$(proxy) && \
# 	forge script --broadcast  --rpc-url ${ETH_RPC_URL} script/Bridge.s.sol:Deploy


# # Bridge local setup.
# bridge_local_setup:
# 	forge script --broadcast  --rpc-url ${ETH_RPC_URL} script/LocalTesting.s.sol:LocalSetup

# # Bridge deposit tokens
# bridge_deposit:
# 	@printf "$(bold)Ensure you don't forget the proxy argument:\n"
# 	@echo "usage: make bridge_deposit config=.yourconfig.env proxy=0x1234"
# 	@printf "$(sgr0)\n"
# 	export BRIDGE_L1_PROXY_ADDRESS=$(proxy) && \
# 	forge script --broadcast  --rpc-url ${ETH_RPC_URL} --sender ${ACCOUNT_ADDRESS} script/Bridge.s.sol:Deposit

# # Bridge withdraw tokens
# bridge_withdraw:
# 	@printf "$(bold)Ensure you don't forget the proxy argument:\n"
# 	@echo "usage: make bridge_withdraw config=.yourconfig.env proxy=0x1234"
# 	@printf "$(sgr0)\n"
# 	export BRIDGE_L1_PROXY_ADDRESS=$(proxy) && \
# 	forge script --broadcast  --rpc-url ${ETH_RPC_URL} --sender ${ACCOUNT_ADDRESS} script/Bridge.s.sol:WithdrawSN

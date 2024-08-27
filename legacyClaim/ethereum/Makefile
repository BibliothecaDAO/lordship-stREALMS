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
	
bridge_claim:
	forge script --broadcast  --rpc-url ${ETH_RPC_URL} script/Bridge.s.sol:ClaimOnStarknet

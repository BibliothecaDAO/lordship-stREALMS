#!/bin/bash
############ STEPS BEFORE RUNNING SCRIPT ############


# ensure caller owns the strealm contract initially so that it can do the
# finishL2Deploy step.


cd bridge/starknet/ && \
scarb --release build && \
cd - && \
cd strealms && \
scarb --release build && \
cd - && \
cd scripts/deployment && \
node startL2Deploy && \
mkdir -p ../../bridge/ethereum/logs/dev && \
cp -r ./addresses/dev ../../bridge/ethereum/logs && \
cd - && \
cd bridge/ethereum/ && \
make bridge_l1_deploy
cd -
cd scripts/deployment && \
mkdir -p ./addresses/dev && \
cp -r ../../bridge/ethereum/logs/dev ./addresses && \
node finishL2Deploy


# remember to change all "dev" to "prod" in production
# here and in the .env file in this directory and .env file
# in bridge/ethereum

############ STEPS AFTER RUNNING SCRIPT ############


# ensure STREALM_REWARD_PAYER approves enough $lords to the l2 strealm contract 
# so that users can claim lords

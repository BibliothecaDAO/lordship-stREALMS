#!/bin/bash
############ STEPS BEFORE RUNNING SCRIPT ############


# ensure caller owns the strealm contract initially so that it can do the
# finishL2Deploy step.


cd ../../starknet/ && \
scarb --release build && \
cd - && \
node startL2Deploy

# remember to change all "dev" to "prod" in production
# here and in the .env file in this directory and .env file
# in bridge/ethereum

############ STEPS AFTER RUNNING SCRIPT ############


# ensure STREALM_REWARD_PAYER approves enough $lords to the l2 strealm contract 
# so that users can claim lords

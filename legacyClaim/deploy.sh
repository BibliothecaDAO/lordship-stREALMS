#!/bin/bash

cd starknet && \
scarb --release build && \
cd scripts/deployment && \
node deployStageOne && \
cp -r ./addresses/ ../../../ethereum/logs/ && \
cd ../../../ethereum && \
forge build && \
make bridge_l1_deploy && \
cp -r ./logs/ ../starknet/scripts/deployment/addresses/ && \
cd ../starknet/scripts/deployment && \
node deployStageTwo
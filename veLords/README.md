## VELORDS

TODO: Add more information about velords contract
<br>
TODO: Add more information about reward pool contract

# LORDS Burner Contract (veLords/src/burner.cairo)

A simple, upgradeable smart contract designed to burn LORDS tokens by sending them to the reward pool.

## Overview

The LORDS Burner contract serves as an intermediary contract that can receive LORDS tokens and allows anyone to trigger the burning mechanism, which transfers the tokens to a designated reward pool.

## Features

- **Upgradeable**: The contract can be upgraded to add new functionality in the future
- **Access Control**: Uses OpenZeppelin's Ownable pattern for administrative functions
- **Permissionless Burning**: Anyone can call the burn function to transfer LORDS to the reward pool

### Public Functions

- `burn_lords()`
  - Burns all LORDS tokens held by the contract by sending them to the reward pool
  - Can be called by anyone
  - Requires the contract to have a non-zero LORDS balance

## Usage

1. Send LORDS tokens to the contract address
2. Call `burn_lords()` to transfer the tokens to the reward pool



## Contract Addresses
### Mainnet 

VeLords: https://starkscan.co/contract/0x047230028629128ac5bfbb384d32f925e70e329b624fc5d82e9c60f5746795cd
<br>
Reward Pool: https://starkscan.co/contract/0x0091b13b83e5c34112aa066a844d4cbe6af99b3d134293829ca1730ea4869a71
<br>
Lords Burner: https://starkscan.co/contract/0x045c587318c9ebcf2fbe21febf288ee2e3597a21cd48676005a5770a50d433c5


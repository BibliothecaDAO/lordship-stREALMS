# NFT Bridge: Ethererum.

This project implements a bridge for transferring ERC721 tokens between Ethereum (L1) and Starknet (L2). The main component is the `Bridge.sol` contract, which handles the deposit and withdrawal of tokens between the two layers from Ethereum.

### Key Features

1. **Token Deposit**: Users can deposit ERC721 tokens from L1 to L2 using the `depositTokens` function.
2. **Token Withdrawal**: Users can withdraw tokens received from L2 using the `withdrawTokens` function.
3. **Request Cancellation**: Users can initiate and complete cancellation of bridge requests using `startRequestCancellation` and `cancelRequest` functions.

### Main Functions

#### `initialize`
Initializes the bridge contract with necessary parameters like the bridge owner address, L1 token(nft) address, Starknet core address, L2 bridge address (on starknet), and L2 bridge selector (on starknet).

#### `depositTokens`
Deposits tokens into escrow and initiates the transfer to Starknet. It requires:
- A salt for generating the request hash
- The new owner's address on Starknet
- An array of token IDs to transfer

#### `withdrawTokens`
Withdraws tokens received from L2. It consumes a message from L2 and transfers the tokens from escrow to the L1 recipient.

#### `startRequestCancellation` and `cancelRequest`
These functions allow users to cancel a bridge request in case of failures or errors in the bridging process. This failure will be as a result of a bug in the l2 bridge contract or where insufficient `msg.value` is given when `depositTokens` is called. Basically, the message must have not been consumed on L2.

See https://docs.starknet.io/architecture-and-concepts/network-architecture/messaging-mechanism on how messaging works on starknet.

### Security Features

- The contract uses OpenZeppelin's UUPS (Universal Upgradeable Proxy Standard) pattern for upgradeability.
- It implements access control to ensure only token owners or admins can initiate cancellations and set important addresses.
- The contract uses escrow mechanisms to hold tokens during the bridging process.




## Setup and Usage

[Foundry for ethereum](https://book.getfoundry.sh/) is used. Once foundry is installed:

1. Install the dependencies

```bash
forge install
```

2. Run the tests

```bash
forge test
```

## To deploy (anvil, testnet, etc...)

First, create a `.yourname.env` file copying the content from `.env.testnet`.
This file will remain ignored by git, and you can put there your credentials
to interact with the network.

Then, you can use the Makefile to operate. Most of variables are taken from
the environment file.

`make bridge_deploy config=.yourname.env`
<br><br><br><br>

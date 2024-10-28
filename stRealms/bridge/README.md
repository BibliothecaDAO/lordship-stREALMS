# Realms Bridge Technical Guide

Realms Bridge is the suite of contracts for easily bridging Realms NFTs between Ethereum and Starknet.

# How it works

Some notations used in this document:
- `L1` refers to Ethereum
- `L2` refers to Starknet
- `Deposit` refers to the process of sending NFTs from L1 to L2
- `Withdrawal` refers to the process of sending NFTs from L2 to L1


### Bridging Realms NFTs from Ethereum to Starknet

1. **Deposit Process, what happens on Ethereum** (`ethereum/src/Bridge.sol`)

      **User Actions:**
      - Approve L1 bridge contract to spend/transfer NFTs
      - Call `depositTokens()` with:
        - Salt value
        - L2 (Starknet) destination address
        - Array of token IDs to bridge

      **Internal Process:**
      - Contract collects NFTs from bridger into escrow via `_depositIntoEscrow()`
      - Generates request hash using salt and transfer details
      - Sends message to L2 bridge contract through Starknet Core contract

2. **Deposit Process, what happens on Starknet** (`starknet/src/bridge.cairo`)

      **Internal Process:**
      - the `withdraw_auto_from_l1` function is called by the Starknet Core contract (because of the #[l1_handler] attribute) with the request object and the sender address (the ethereum bridge contract address)
	  - the contract verifies that the sender is the actual ethereum bridge contract address we know of. If not, it reverts.
      - the contract then iterates over the token ids, and for each id:
        - calls the `safe_mint()` function on the L2 token contract to mint the token to the destination address. This means that the starknet bridge contract must have permission to mint tokens on the starknet realms contract.
        - we then emit a `WithdrawRequestCompleted` event with the request hash, timestamp and the request object

3. **Cancellation Process**

	It is possible to cancel a request if a deposit is not processed on starknet for whatever reason. e.g there is a bug in the starknet contract which causes the `withdraw_auto_from_l1` function to revert with an error.

   If the message sent from the L1 bridge contract to the L2 bridge contract fails to process:
   - The previous token owner or bridge admin can call `startRequestCancellation()` with the request object and nonce used by the starknet core contract when processing the message that failed. 

   - This process starts a waiting period (currently 5 days ) more here: [Starknet docs](https://docs.starknet.io/architecture-and-concepts/network-architecture/messaging-mechanism/#l2-l1_message_cancellation)

   - After waiting the required period, anyone can call the `cancelRequest()` function to return the tokens from escrow to the original owner



### Bridging from Starknet to Ethereum

1. **Withdrawal Process, what happens on Starknet** (`starknet/src/bridge.cairo`)

      **User Actions:**

    - Approve L2 bridge contract to spend/transfer NFTs
	- User calls `deposit_tokens()` function with:
		- Salt value
		- L1 (Ethereum) destination address
		- Array of token IDs to bridge

	**Internal Process:**
	- the contract collects the NFTs from the user and burns them
	- sends a message to the L1 bridge contract through the Starknet Core contract

2. **Withdrawal Process, what happens on Ethereum** (`ethereum/src/Bridge.sol`)
      **User Actions:**
	  - withdrawal is not done automatically, so the user must call the `withdrawTokens()` function

      **Internal Process:**
	  - inside the `withdrawTokens()` function, the contract consumes a starknet message and verifies that the sender is the actual starknet bridge contract address we know of. If not, it reverts.
	
	  - the contract then iterates over the token ids, and transfers each nft to the specified recipient address
	  - emits a `WithdrawRequestCompleted` event with the request hash, timestamp and the request object


some more notes:
- the l1 bridge contract is upgradeable and deployed behind a proxy
- the l2 bridge contract is upgradeable
- both bridge contracts are owned by a trusted admin


# Contract Addresses:

**Mainnet**
- ethereum (L1) bridge: https://etherscan.io/address/0xa425fa1678f7a5dafe775bea3f225c4129cdbd25
- starknet (L2) bridge: https://starkscan.co/contract/0x013ae4e41ff29ee8311c84b024ac59a0c13f73fa1ba0cea02fbbf7880ec4835a#transactions

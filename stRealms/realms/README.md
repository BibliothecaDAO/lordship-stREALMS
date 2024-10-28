# Realms L2 Contract

> A technical guide to the Realms NFT contract on Starknet.

The Realms L2 contract implements a token streaming mechanism for Realms NFT holders on Starknet, enabling continuous per-second distribution of `$LORDS` tokens to delegated NFT holders.

## Architecture Overview

### Core Components

#### 1. StRealmComponent
*Location: `src/components/strealm.cairo`*

The heart of the token streaming system, implementing the core streaming logic and reward distribution mechanisms. It manages:
- Token stream initialization and updates
- Reward calculations and claims
- Stream Flow rate management
- Individual streamed reward state tracking

#### 2. ERC721VotesComponent
*Location: `src/components/erc721/extensions/erc721_votes.cairo`*

An enhanced version of OpenZeppelin's ERC20Votes component (v0.13.0), adapted for ERC721 tokens with custom delegation hooks, allowing for pre/post delegation event handling.

### Primary Contracts

#### 1. StRealm Contract
*Location: `src/contracts/strealm.cairo`*

The main contract orchestrating all components:
- Integrates AccessControlComponent
- Integrates UpgradeableComponent
- Integrates ERC721Component
- Implements ERC721VotesComponent
- Manages StRealmComponent
- Interfaces with RealmMetadata contract

#### 2. RealmMetadata Contract
*Location: `src/contracts/metadata/metadata.cairo`*

A separate contract handling all metadata operations:
- Metadata encoding/decoding
- Token URI management
- Separated from main contract to avoid size constraints

## Technical Overview

## Stream Mechanics

#### Flows and Streams
The streaming system operates on two key structures:

##### 1. Flow Structure
```cairo
struct Flow {
    rate: u256,    // Tokens streamed per second
    end_at: u64    // Flow expiration timestamp
}
```

**Key Characteristics:**
- Unique `flow_id` increments with each rate change
- Previous flows are terminated when new rates are set
- Global configuration affecting all streams

##### 2. Stream Structure
```cairo
struct Stream {
    flow_id: u64,  // Active flow rate identifier
    start_at: u64  // Stream start timestamp
}
```

**Key Characteristics:**
- One active stream per address
- Links to current flow configuration
- Automatically updates on transfers/delegations

### Stream Lifecycle

#### 1. Stream Activation
- Triggered by Realm NFT delegation
- Uses current global flow rate
- Multiple NFTs multiply streaming rate

#### 2. Stream Updates
When global flow rate changes:
- All existing streams are forced to stop
- Users must reactivate their streams:

  **For Previously Delegated Users:**
  - Option A: Delegate to zero address then re-delegate
  - Option B: Transfer any one of their NFTs (even to self)
  
  **For New Users:**
  - Simply delegate their token

#### 3. Reward Calculation
```
reward = num_staked_realms × stream_duration × flow_rate
```
Where:
- `num_staked_realms`: Delegated Realms NFT count
- `stream_duration`: Time since stream start
- `flow_rate`: Current tokens per second rate

### Stream State Management
- Automatic balance updates on transfers
- Stream resets after reward claims
- Flow rate changes require stream reactivation
- Delegation status affects stream activity

<br><br>
## Metadata Mechanics
All metadata is stored on chain and retrieved via the `RealmMetadata` contract.
The actual data can be found in `stRealms/realms/src/data/metadata.cairo` and the compression algorithims can be found in `stRealms/_scripts/metadata`.

The Realms metadata system uses a compression and encoding scheme to efficiently store and serve the NFT's metadata on-chain. The system splits metadata into three main components:
- Name and Attributes
- URL Part A
- URL Part B

#### Architecture

##### Core Components

1. **RealmMetadata Contract**
   - Main contract coordinating metadata retrieval
   - Interfaces with three separate metadata storage contracts:
     - NameAndAttrsMetadata
     - URLPartAMetadata
     - URLPartBMetadata
   - The metadata is separated into three contracts to avoid the contract size limit on Starknet.

2. **Metadata Storage Contracts**

Each storage contract holds a portion of the compressed metadata:

```cairo
#[starknet::contract]
mod NameAndAttrsMetadata {
    fn data(self: @ContractState, token_id: u16) -> felt252 {
        compressed_name_and_attrs(token_id.into())
    }
}

#[starknet::contract]
mod URLPartAMetadata {
    fn data(self: @ContractState, token_id: u16) -> felt252 {
        compressed_url_first(token_id.into())
    }
}

#[starknet::contract]
mod URLPartBMetadata {
    fn data(self: @ContractState, token_id: u16) -> felt252 {
        compressed_url_second(token_id.into())
    }
}
```

#### Data Structure

##### Name and Attributes Encoding
The name and attributes are packed into a single felt252 with the following structure:
```
[name (bytes of variable length)] [attributes (bytes of variable length)] [name_len (1 byte)][attrs_len (1 byte)] 
```
Where:
- `name`: The realm name string
- `attributes`: Packed attribute values
- `name_len`: Length of the name in bytes (1 byte)
- `attrs_len`: Number of attributes (1 byte)

e.g using `0x53746f6c736c69010102011a1108060708` as an example encoded felt252 containing the name and metadat for the realm named `Stolsli`, it would be decoded as so
```
0x53746f6c736c69 // name
0x010102011a110806 // attributes
0x07 // name_len
0x08 // attrs_len
```

##### Attributes Format
Attributes are further split (per byte) and reversed and encoded as follows:
--> The split attributes would be 
`[0x01, 0x01, 0x02, 0x01, 0x1a, 0x11, 0x08, 0x06]`
--> The reversed attributes would be 
`[0x06, 0x08, 0x11, 0x1a, 0x01, 0x02, 0x01, 0x01]`

The attributes are then further decoded as follows:
- Region (1 byte) <--- always the first byte (0x06)
- Cities (1 byte) <--- always the second byte (0x08)
- Harbors (1 byte) <--- always the third byte (0x11)
- Rivers (1 byte) <--- always the fourth byte (0x1a)
- Resources (bytes of variable length) <--- the remaining bytes (0x01, 0x02)
- Order (1 byte) <--- always the second to last byte (0x01)
- Wonder (1 byte) <--- always the last byte (0x01)

The system includes mappings for:
- Orders (16 different types)
- Wonders (51 different types)
- Resources (22 different types)
as defined in `src/contracts/metadata/utils.cairo`

Each mapping converts numeric values to their corresponding string representations.e.g `order_mapping` shows that order (0x01) is `The Order of Giants`.




##### Image URL Encoding
The IPFS URL is split into two parts (URL_Part_A and URL_Part_B) of 23 bytes (e.g "0x516d56567770376f657544396635467643593543336a6f", "0x3836336d324c547a735a656359384e58777678756b5564") which are concatenated to form a full token identifier (e.g QmVVwp7oeuD9f5FvCY5C3jo863m2LTzsZecY8NXwvxukUd) which is later converted to a full URL e.g https://gateway.pinata.cloud/ipfs/QmVVwp7oeuD9f5FvCY5C3jo863m2LTzsZecY8NXwvxukUd. They were split this way because of size constraints on Starknet.

the urls are concatenated by creating a ByteArray and appending the two felt252 parts: i.e
```
    // create url
    let (url_part_a, url_part_b) = url;
    let mut url_str: ByteArray = "";
    url_str.append_word(url_part_a, URL_PART_LEN); // URL_PART_LEN is 23 bytes
    url_str.append_word(url_part_b, URL_PART_LEN); // URL_PART_LEN is 23 bytes
```


#### Full Metadata Retrieval Process

In order to get the full decoded metadata, we can use the following function:
```cairo
fn get_decoded_metadata(self: @ContractState, token_id: u16) -> ByteArray {
    let (encoded_name_and_attrs, encoded_url_a, encoded_url_b) = self.get_encoded_metadata(token_id);
    make_json_and_base64_encode_metadata(
        encoded_name_and_attrs, 
        (encoded_url_a, encoded_url_b)
    )
}
```
which first gets the three encoded felt252 parts and then uses them to construct a JSON in the following format: 
```json
{
    "name": "<realm_name>",
    "image": "https://gateway.pinata.cloud/ipfs/<concatenated_url>",
    "attributes": [
        {"trait_type": "Regions", "value": "<value>"},
        {"trait_type": "Cities", "value": "<value>"},
        {"trait_type": "Harbors", "value": "<value>"},
        {"trait_type": "Rivers", "value": "<value>"},
        {"trait_type": "Resource", "value": "<value>"},
        {"trait_type": "Wonder", "value": "<value>"},
        {"trait_type": "Order", "value": "<value>"}
    ]
}
```
then this JSON is base64 encoded and returned in the following format:
`data:application/json;base64,<encoded_json>`
which will work on any browser.




This metadata system provides an efficient way to store and serve Realms NFT metadata entirely on-chain while maintaining gas efficiency through careful compression and encoding.




## Contract Addresses

### Starknet Mainnet 
Realms L2 Contract:<br> https://starkscan.co/nft-contract/0x07ae27a31bb6526e3de9cf02f081f6ce0615ac12a6d7b85ee58b8ad7947a2809

Realms Metadata:<br> https://starkscan.co/contract/0x04607b156e1e09e194697a02fd6f71bdd121dca4ef5f74488c489fde1f07a575

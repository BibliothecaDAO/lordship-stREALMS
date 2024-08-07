// // SPDX-License-Identifier: MIT
// pragma solidity ^0.8.0;

// import "forge-std/Script.sol";

// import "./Utils.sol";
// import "../test/token/ERC721MintFree.sol";
// import "openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol";


// contract Deploy is Script {

//     function setUp() public {}

//     function run() public {
//         Config memory config = Utils.loadConfig();
        
//         vm.startBroadcast(config.deployerPrivateKey);

//         address _address = address(new ERC721MintFree("Test Realm", "TREALM"));
    
//         vm.stopBroadcast();

//         string memory json = "l1_sepolia_erc721";
//         vm.serializeString(json, "contract_address", vm.toString(_address));
//         Utils.writeJson(json, "l1_sepolia_erc721.json");
//     }
// }

// contract Mint is Script {

//     function setUp() public {}

//     function run() public {
//         Config memory config = Utils.loadConfig();
        
//         vm.startBroadcast(config.deployerPrivateKey);

//         ERC721MintFree(config.l1TokenAddress)
//             .mintRangeFree(config.ownerAddress, 50, 80);
    
//         vm.stopBroadcast();
//     }
// }

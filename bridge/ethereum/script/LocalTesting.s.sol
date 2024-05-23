// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

// import "forge-std/Script.sol";

// import "./Utils.sol";
// import "src/Bridge.sol";
// import "src/IBridge.sol";
// import "src/sn/Cairo.sol";
// import "src/sn/StarknetMessagingLocal.sol";
// import "src/token/ERC721Bridgeable.sol";

// import "openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol";
// import "openzeppelin-contracts/contracts/token/ERC721/IERC721.sol";


// /**
//    Deploys a local setup with:
//    1. Local SN Core contract to receive/send messages.
//    2. Realms bridge.
//    3. One ERC721b collection with 10 tokens minted for the deployer.
//    4. One request on the bridge depositing tokens.
// */
// contract LocalSetup is Script {
//     function setUp() public {}

//     function run() public {
//         Config memory config = Utils.loadConfig();

//         string memory json = "realms_local_testing";
//         vm.startBroadcast(config.deployerPrivateKey);

//         // Local starknet core messaging.
//         address snCoreAddress = address(new StarknetMessagingLocal());

//         // Realms.
//         address realmsImpl = address(new Realms());

//         bytes memory dataInit = abi.encodeWithSelector(
//             Realms.initialize.selector,
//             abi.encode(
//                 config.deployerAddress,
//                 snCoreAddress,
//                 config.l2BridgeAddress,
//                 config.l2BridgeSelector
//             )
//         );
//         address realmsProxyAddress = address(new ERC1967Proxy(realmsImpl, dataInit));

//         // ERC721b.
//         address erc721Impl = address(new ERC721Bridgeable());

//         bytes memory erc721DataInit = abi.encodeWithSelector(
//             ERC721Bridgeable.initialize.selector,
//             abi.encode(
//                 "collection_1",
//                 "C1"
//             )
//         );

//         address erc721ProxyAddress = address(new ERC1967Proxy(erc721Impl, erc721DataInit));

//         vm.serializeString(json, "sncore_address", vm.toString(snCoreAddress));
//         vm.serializeString(json, "realms_proxy_address", vm.toString(realmsProxyAddress));
//         vm.serializeString(json, "realms_impl_address", vm.toString(realmsImpl));
//         vm.serializeString(json, "erc721b_proxy_address", vm.toString(erc721ProxyAddress));
//         vm.serializeString(json, "erc721b_impl_address", vm.toString(erc721Impl));

//         // Mint some tokens.
//         (bool success, bytes memory data) = erc721ProxyAddress.call(
//             abi.encodeWithSignature(
//                 "mintRangeFree(address,uint256,uint256)",
//                 config.deployerAddress,
//                 0,
//                 20
//             )
//         );

//         // set approval to then deposit tokens.
//         IERC721(erc721ProxyAddress).setApprovalForAll(realmsProxyAddress, true);

//         // Deposit some.
//         uint256[] memory ids = new uint256[](2);
//         ids[0] = 1;
//         ids[1] = 2;

//         uint256 salt = 0x1;
//         snaddress to = Cairo.snaddressWrap(0x12345);

//         IBridge(realmsProxyAddress).depositTokens{value: 30000}(
//             salt,
//             address(erc721ProxyAddress),
//             to,
//             ids,
//             false
//         );

//         vm.stopBroadcast();

//         Utils.writeJson(json, "realms_local_testing.json");
//     }
// }

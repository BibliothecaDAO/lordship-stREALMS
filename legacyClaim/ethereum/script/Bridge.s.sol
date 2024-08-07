// // SPDX-License-Identifier: UNLICENSED
// pragma solidity ^0.8.0;

// import "forge-std/Script.sol";

// import "./Utils.sol";
// import "../src/Bridge.sol";
// import "../src/sn/Cairo.sol";
// import "../src/sn/StarknetMessagingLocal.sol";
// import "../test/token/ERC721MintFree.sol";

// import "openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol";
// import "openzeppelin-contracts/contracts/token/ERC721/IERC721.sol";
// import "openzeppelin-contracts/contracts/access/Ownable.sol";


// contract Deploy is Script {
//     function setUp() public {}

//     function run() public {
//         Config memory config = Utils.loadConfig();

//         vm.startBroadcast(config.deployerPrivateKey);

//         address snCoreAddress = config.starknetCoreAddress;

//         string memory l2BridgePath = string.concat(vm.envString("LOCAL_LOGS"),"l2_bridge.json");
//         string memory fileContent = vm.readFile(l2BridgePath);
//         bytes32 l2BridgeAddressBytes = abi.decode(vm.parseJson(fileContent, ".address"), (bytes32));
//         uint256 l2BridgeAddress = uint256(l2BridgeAddressBytes);


//         bytes memory dataInit = abi.encodeWithSelector(
//             Bridge.initialize.selector,
//             abi.encode(
//                 config.ownerAddress,
//                 config.l1TokenAddress,
//                 config.starknetCoreAddress,
//                 l2BridgeAddress,
//                 config.l2BridgeSelector
//             )
//         );
//         address impl = address(new Bridge());
//         address proxyAddress = address(new ERC1967Proxy(impl, dataInit));

//         // upgrade 
//         // Bridge(payable(proxyAddress)).upgradeToAndCall(impl, dataInit);

//         vm.stopBroadcast();

//         string memory json = "l1_bridge";
//         vm.serializeString(json, "proxy_address", vm.toString(proxyAddress));
//         vm.serializeString(json, "impl_address", vm.toString(impl));
//         vm.serializeString(json, "sncore_address", vm.toString(snCoreAddress));
//         Utils.writeJson(json, "l1_bridge.json");
//     }
// }


// contract TransferOwnership is Script {
//     function setUp() public {}

//     function run() public {
//         Config memory config = Utils.loadConfig();

//         vm.startBroadcast(config.deployerPrivateKey);

//         ERC721MintFree(config.l1TokenAddress)
//             .mintRangeFree(config.deployerAddress, 4, 6);


//         uint256[] memory ids = new uint256[](3);
//         ids[0] = 4;
//         ids[1] = 5;
//         ids[2] = 6;

//         string memory l1BridgePath = string.concat(vm.envString("LOCAL_LOGS"),"l1_bridge.json");
//         string memory fileContent = vm.readFile(l1BridgePath);
//         bytes32 l1BridgeAddressBytes = abi.decode(vm.parseJson(fileContent, ".data.proxy_address"), (bytes32));
//         address proxyAddress =address(uint160(uint256(l1BridgeAddressBytes)));

//         IERC721(config.l1TokenAddress).setApprovalForAll(proxyAddress, true);
//         Bridge(payable(proxyAddress)).depositTokens{value: 50000}(
//             0x1, // salt
//             Cairo.snaddressWrap(0x0272fB197B288aB6A441B80a60F60EeF66fF7D5E9d8adc4F1D45fB3D9a0C4205), // recipient
//             ids // token ids 
//         );

//         vm.stopBroadcast();
//     }
// }

// contract SetOwnership is Script {
//     function setUp() public {}

//     function run() public {
//         Config memory config = Utils.loadConfig();
//         vm.startBroadcast(config.deployerPrivateKey);
//         address impl = address(0x9c30e0be313bc7Ef4F8CCE38C12734b502EcdeD3);
//         address proxy = address(0xA425Fa1678f7A5DaFe775bEa3F225c4129cdbD25);
//         Ownable(impl)
//             .transferOwnership(address(0xBbae2e00bcc495913546Dfaf0997Fb18BF0F20fe));
//         Ownable(proxy)
//             .transferOwnership(address(0xBbae2e00bcc495913546Dfaf0997Fb18BF0F20fe));
//         vm.stopBroadcast();
//     }
// }

// // contract WithdrawSN is Script {
// //     function setUp() public {}

// //     function run() public {
// //         Config memory config = Utils.loadConfig();

// //         vm.startBroadcast(config.deployerPrivateKey);

// //         address proxyAddress = config.bridgeL1ProxyAddress;

// //         uint256[] memory buf = new uint256[](21);
// //         buf[0] = 257;
// //         buf[1] = 157109796990335246573763232927628717774;
// //         buf[2] = 36809199904600870044403989700573533027;
// //         buf[3] = 0;
// //         buf[4] = 1530138567501442454218839542491331524400566329265365463560792648116878965926;
// //         buf[5] = 1260237688642687788759567135567789255041174512757;
// //         buf[6] = 456385480641843693338102106303024284830032106430299072071775148436454636113;
// //         buf[7] = 1;
// //         buf[8] = 113715322580273;
// //         buf[9] = 1;
// //         buf[10] = 1196182833;
// //         buf[11] = 1;
// //         buf[12] = 0;
// //         buf[13] = 1;
// //         buf[14] = 20;
// //         buf[15] = 0;
// //         buf[16] = 0;
// //         buf[17] = 1;
// //         buf[18] = 1;
// //         buf[19] = 0;
// //         buf[20] = 0;

// //         Bridge(payable(proxyAddress)).withdrawTokens(buf);

// //         vm.stopBroadcast();
// //     }
// // }

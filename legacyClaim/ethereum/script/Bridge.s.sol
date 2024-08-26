// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/Script.sol";

import "./Utils.sol";
import "../src/Bridge.sol";
import "../src/sn/Cairo.sol";
import "../src/sn/StarknetMessagingLocal.sol";
import "../test/token/ERC721MintFree.sol";

import "openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "openzeppelin-contracts/contracts/token/ERC721/IERC721.sol";
import "openzeppelin-contracts/contracts/access/Ownable.sol";


contract Deploy is Script {
    function setUp() public {}

    function run() public {
        Config memory config = Utils.loadConfig();

        vm.startBroadcast(config.deployerPrivateKey);

        address snCoreAddress = config.starknetCoreAddress;

        string memory l2BridgePath = string.concat(vm.envString("LOCAL_LOGS"),"l2_bridge.json");
        string memory fileContent = vm.readFile(l2BridgePath);
        bytes32 l2BridgeAddressBytes = abi.decode(vm.parseJson(fileContent, ".address"), (bytes32));
        uint256 l2BridgeAddress = uint256(l2BridgeAddressBytes);
        bytes memory dataInit = abi.encodeWithSelector(
            Bridge.initialize.selector,
            abi.encode(
                config.ownerAddress,
                config.starknetCoreAddress,
                l2BridgeAddress,
                config.l2BridgeSelector
            )
        );
        address impl = address(new Bridge());
        address proxyAddress = address(new ERC1967Proxy(impl, dataInit));

        Ownable(impl)
            .transferOwnership(address(config.l1BridgeActualOwnerAddress));
        Ownable(proxyAddress)
            .transferOwnership(address(config.l1BridgeActualOwnerAddress));

        vm.stopBroadcast();

        string memory json = "l1_bridge";
        vm.serializeString(json, "proxy_address", vm.toString(proxyAddress));
        vm.serializeString(json, "impl_address", vm.toString(impl));
        vm.serializeString(json, "sncore_address", vm.toString(snCoreAddress));
        Utils.writeJson(json, "l1_bridge.json");
    }
}



contract ClaimOnStarknet is Script {
    function setUp() public {}

    function run() public {
        Config memory config = Utils.loadConfig();

        vm.startBroadcast(config.deployerPrivateKey);


        string memory l1BridgePath = string.concat(vm.envString("LOCAL_LOGS"),"l1_bridge.json");
        string memory fileContent = vm.readFile(l1BridgePath);
        bytes32 l1BridgeProxyAddressBytes = abi.decode(vm.parseJson(fileContent, ".data.proxy_address"), (bytes32));
        address proxyAddress =address(uint160(uint256(l1BridgeProxyAddressBytes)));

        snaddress claimRecipientAddress = Cairo.snaddressWrap(0x0272fB197B288aB6A441B80a60F60EeF66fF7D5E9d8adc4F1D45fB3D9a0C4205);
        uint16 claimId = 4;
        Bridge(payable(proxyAddress)).claimOnStarknet{value: 50000}(
            claimRecipientAddress, // recipient
            claimId
        );
        vm.stopBroadcast();
    }
}



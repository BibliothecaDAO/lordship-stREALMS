pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "forge-std/Vm.sol";

address constant HEVM_ADDRESS = address(bytes20(uint160(uint256(keccak256("hevm cheat code")))));

struct Config {
    address ownerAddress;
    address l1TokenAddress;
    address deployerAddress;
    uint256 deployerPrivateKey;

    address starknetCoreAddress;
    address bridgeL1ProxyAddress;

    uint256 l2BridgeSelector;
}

library Utils {

    //
    function loadConfig()
        internal
        view
        returns (Config memory) {
        VmSafe vm = VmSafe(HEVM_ADDRESS);
        
        return Config({
            ownerAddress: vm.envAddress("BRIDGE_L1_OWNER_ADDRESS"),
            l1TokenAddress: vm.envAddress("BRIDGE_L1_TOKEN_ADDRESS"),
            
            deployerAddress: vm.envAddress("DEPLOYMENT_ACCOUNT_ADDRESS"),
            deployerPrivateKey: vm.envUint("DEPLOYMENT_ACCOUNT_PRIVATE_KEY"),

            starknetCoreAddress: vm.envAddress("STARKNET_CORE_L1_ADDRESS"),
            bridgeL1ProxyAddress: vm.envAddress("BRIDGE_L1_PROXY_ADDRESS"),
            
            l2BridgeSelector: vm.envUint("BRIDGE_L2_SELECTOR")
            });
    }

    //
    function writeJson(string memory json, string memory fileName)
        internal {
        VmSafe vm = VmSafe(HEVM_ADDRESS);

        string memory data = vm.serializeBool(json, "success", true);
        string memory outJson = "out";
        string memory output = vm.serializeString(outJson, "data", data);

        string memory localLogs = vm.envString("LOCAL_LOGS");
        vm.createDir(localLogs, true);
        vm.writeJson(output, string.concat(localLogs, fileName));
    }
}

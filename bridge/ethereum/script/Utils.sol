pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "forge-std/Vm.sol";

address constant HEVM_ADDRESS = address(bytes20(uint160(uint256(keccak256("hevm cheat code")))));

struct Config {
    address deployerAddress;
    uint256 deployerPrivateKey;

    address starknetCoreAddress;
    address realmsL1ProxyAddress;

    uint256 realmsL2Address;
    uint256 realmsL2Selector;
}

library Utils {

    //
    function loadConfig()
        internal
        view
        returns (Config memory) {
        VmSafe vm = VmSafe(HEVM_ADDRESS);
        
        return Config({
            deployerAddress: vm.envAddress("ACCOUNT_ADDRESS"),
            deployerPrivateKey: vm.envUint("ACCOUNT_PRIVATE_KEY"),

            starknetCoreAddress: vm.envAddress("STARKNET_CORE_L1_ADDRESS"),
            realmsL1ProxyAddress: vm.envAddress("REALMS_L1_PROXY_ADDRESS"),

            realmsL2Address: vm.envUint("REALMS_L2_ADDRESS"),
            realmsL2Selector: vm.envUint("REALMS_L2_SELECTOR")
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

import colors from "colors";
import {setL1BridgeAddressInL2Bridge, setOwnerAddressInL2Bridge } from "./libs/commands.js";
import { getDeployedAddress, getProxyAddress } from "./libs/common.js";

console.log(`   ____      _ _ `.red);
console.log(`  / ___|__ _| | |`.red);
console.log(` | |   / _\` | | |`.red);
console.log(` | |__| (_| | | |`.red);
console.log(`  \\____\\__,_|_|_|`.red);

const l1_bridge = await getProxyAddress("l1_bridge");
const l2_bridge = await getDeployedAddress("l2_bridge");

console.log("\n");
console.log({ l1_bridge, l2_bridge });
console.log("\n");

await setL1BridgeAddressInL2Bridge(l2_bridge, l1_bridge);
const l2_final_admin = "0x" + BigInt(process.env.L2_BRIDGE_FINAL_ADMIN).toString(16);
await setOwnerAddressInL2Bridge(l2_bridge, l2_final_admin);
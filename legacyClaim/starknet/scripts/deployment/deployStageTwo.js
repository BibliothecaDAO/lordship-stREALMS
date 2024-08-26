import colors from "colors";
import {setL1BridgeAddressInL2Bridge, setOwnerAddressInL2Bridge } from "./libs/commands.js";
import { getDeployedAddress } from "./libs/common.js";

console.log(`   ____      _ _ `.red);
console.log(`  / ___|__ _| | |`.red);
console.log(` | |   / _\` | | |`.red);
console.log(` | |__| (_| | | |`.red);
console.log(`  \\____\\__,_|_|_|`.red);

const l1_bridge = await getDeployedAddress("l1_bridge");
const l2_bridge = await getDeployedAddress("l2_bridge");
await setL1BridgeAddressInL2Bridge(l2_bridge, l1_bridge);

const l2_final_admin = BigInt(process.env.L2_BRIDGE_FINAL_ADMIN);
await setOwnerAddressInL2Bridge(l2_bridge, l2_final_admin);
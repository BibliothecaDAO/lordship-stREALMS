import "dotenv/config";
import * as path from "path";
import { fileURLToPath } from "url";
import { getNetwork, getAccount } from "./network.js";
import { declare, getPath } from "./common.js";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const TARGET_PATH = path.join(
  __dirname,
  "..",
  "..",
  "..",
  "bridge",
  "starknet",
  "target",
  "release"
);





export const deploy = async (BRIDGE_ADMIN, BRIDGE_L1_ADDRESS) => {
  ///////////////////////////////////////////
  ////////    L2 Bridge         /////////////
  ///////////////////////////////////////////

  // Load account
  const account = getAccount();

  // declare contract
  let realName = "Bridge L2 Contract";
  let contractName = "bridge";
  const class_hash = (
    await declare(getPath(TARGET_PATH, contractName), realName)
  ).class_hash;

  let constructorCalldata = [BRIDGE_ADMIN, BRIDGE_L1_ADDRESS];

  // Deploy contract
  console.log(`\nDeploying ${realName} ... \n\n`.green);
  let contract = await account.deployContract({
    classHash: class_hash,
    constructorCalldata: constructorCalldata,
  });

  // Wait for transaction
  let network = getNetwork(process.env.STARKNET_NETWORK);
  console.log(
    "Tx hash: ".green,
    `${network.explorer_url}/tx/${contract.transaction_hash})`
  );
  let a = await account.waitForTransaction(contract.transaction_hash);
  console.log("Contract Address: ".green, contract.address, "\n\n");
};



export const deployl2Bridge = async () => {
  let BRIDGE__ADMIN =
    0x06a4d4e8c1cc9785e125195a2f8bd4e5b0c7510b19f3e2dd63533524f5687e41n;
  let BRIDGE__L1_BRIDGE_ADDRESS =0x0n;
  let BRIDGE__L2_TOKEN_ADDRESS =
    0x2b80629170ef5d194b661bc2a2cec1ec24acc47d36a40a1f88bf6aee3f986e5n;
  await deploy(BRIDGE__ADMIN, BRIDGE__L1_BRIDGE_ADDRESS, BRIDGE__L2_TOKEN_ADDRESS);
};

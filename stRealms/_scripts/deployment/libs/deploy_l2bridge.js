import "dotenv/config";
import * as path from "path";
import { fileURLToPath } from "url";
import { declare, getContractPath, deploy } from "./common.js";

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



export const deployl2Bridge = async () => {
  ///////////////////////////////////////////
  ////////    L2 Bridge         /////////////
  ///////////////////////////////////////////

  let BRIDGE__ADMIN = BigInt(process.env.BRIDGE_L2_ADMIN);
  let BRIDGE__L1_BRIDGE_ADDRESS = 0x0;
  let BRIDGE__L2_TOKEN_ADDRESS = 0x0;

  // declare contract
  let realName = "l2_bridge";
  let contractName = "bridge";
  const class_hash = (
    await declare(getContractPath(TARGET_PATH, contractName), realName)
  ).class_hash;

  let constructorCalldata = [
    BRIDGE__ADMIN,
    BRIDGE__L1_BRIDGE_ADDRESS,
    BRIDGE__L2_TOKEN_ADDRESS,
  ];

  let contract_address = await deploy(realName, class_hash, constructorCalldata);
};


export const setl1AddressesInl2Bridge = async () => {
  ///////////////////////////////////////////
  ////////    Set L1 Addresses      /////////
  ///////////////////////////////////////////

  let BRIDGE__ADMIN = BigInt(process.env.BRIDGE_L2_ADMIN);
  let BRIDGE__L1_BRIDGE_ADDRESS = 0x0;
  let BRIDGE__L2_TOKEN_ADDRESS = 0x0;

  // declare contract
  let realName = "l2_bridge";
  let contractName = "bridge";
  const class_hash = (
    await declare(getContractPath(TARGET_PATH, contractName), realName)
  ).class_hash;

  let constructorCalldata = [
    BRIDGE__ADMIN,
    BRIDGE__L1_BRIDGE_ADDRESS,
    BRIDGE__L2_TOKEN_ADDRESS,
  ];

  let contract_address = await deploy(
    realName,
    class_hash,
    constructorCalldata
  );
};
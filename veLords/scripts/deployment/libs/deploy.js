import "dotenv/config";
import * as path from "path";
import { fileURLToPath } from "url";
import { declare, getContractPath, deploy } from "./common.js";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const TARGET_PATH = path.join(__dirname, "..", "..", "..", "target", "release");



export const deployVeLords = async () => {
  ///////////////////////////////////////////
  ////////    VeLords           /////////////
  ///////////////////////////////////////////

  // declare contract
  let realName = "Lordship veLords";
  let contractName = "lordship_velords";
  const class_hash = (
    await declare(getContractPath(TARGET_PATH, contractName), realName)
  ).class_hash;

  // deploy contract
  let VELORDS_LORDS_TOKEN = BigInt(process.env.VELORDS_LORDS_TOKEN);
  let VELORDS_ADMIN = BigInt(process.env.VELORDS_ADMIN);
  let constructorCalldata = [VELORDS_LORDS_TOKEN, VELORDS_ADMIN];
  let address = await deploy(realName, class_hash, constructorCalldata);
  return address;
};


export const deployDLords = async () => {
  ///////////////////////////////////////////
  ////////       DLords         /////////////
  ///////////////////////////////////////////

  // declare contract
  let realName = "Lordship dLords";
  let contractName = "lordship_dlords";
  const class_hash = (
    await declare(getContractPath(TARGET_PATH, contractName), realName)
  ).class_hash;

  // deploy contract
  let DLORDS_ADMIN = BigInt(process.env.DLORDS_ADMIN);
  let constructorCalldata = [DLORDS_ADMIN];
  let address = await deploy(realName, class_hash, constructorCalldata);
  return address;
};


export const deployRewardPool = async (veLordsAddress, dLordsAddress) => {
  ///////////////////////////////////////////
  ////////       Reward Pool    /////////////
  ///////////////////////////////////////////

  // declare contract
  let realName = "Lordship veLords Reward Pool";
  let contractName = "lordship_reward_pool";
  const class_hash = (
    await declare(getContractPath(TARGET_PATH, contractName), realName)
  ).class_hash;

  // deploy contract
  let RP_ADMIN = BigInt(process.env.REWARD_POOL_ADMIN);
  let RP_VELORDS_ADDRESS = veLordsAddress;
  let RP_DLORDS_ADDRESS = dLordsAddress;
  let RP_TIMESTAMP_NOW = Math.round(Date.now() / 1000);
  let constructorCalldata = [
    RP_ADMIN,
    RP_VELORDS_ADDRESS,
    RP_DLORDS_ADDRESS, 
    RP_TIMESTAMP_NOW
  ];
  await deploy(realName, class_hash, constructorCalldata);
};


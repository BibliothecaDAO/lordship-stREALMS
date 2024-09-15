import "dotenv/config";
import * as path from "path";
import { fileURLToPath } from "url";
import { declare, getContractPath, deploy } from "./common.js";
import { getAccount, getNetwork } from "./network.js";

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
  let LORDS_TOKEN = BigInt(process.env.LORDS_TOKEN);
  let VELORDS_ADMIN = BigInt(process.env.VELORDS_ADMIN);
  let constructorCalldata = [LORDS_TOKEN, VELORDS_ADMIN];
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


export const deployRewardPool = async (veLordsAddress) => {
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
  let RP_REWARD_TOKEN_ADDRESS = BigInt(process.env.LORDS_TOKEN);
  let RP_TIMESTAMP_NOW = Math.round(Date.now() / 1000);
  let constructorCalldata = [
    RP_ADMIN,
    RP_VELORDS_ADDRESS,
    RP_REWARD_TOKEN_ADDRESS, 
    RP_TIMESTAMP_NOW
  ];
  let address = await deploy(realName, class_hash, constructorCalldata);
  return address
};

export const deployLordsBurner = async (rewardPoolAddress) => {
  ///////////////////////////////////////////
  ////////       Lords Burner     ///////////
  ///////////////////////////////////////////

  // declare contract
  let realName = "Lordship Lords Burner";
  let contractName = "lordship_burner";
  const class_hash = (
    await declare(getContractPath(TARGET_PATH, contractName), realName)
  ).class_hash;

  // deploy contract
  let LORDS_BURNER_ADMIN = BigInt(process.env.FINAL_ADMIN);
  let LORDS_BURNER_REWARD_POOL = rewardPoolAddress;
  let constructorCalldata = [
    LORDS_BURNER_ADMIN,
    LORDS_BURNER_REWARD_POOL,
  ];
  let address = await deploy(realName, class_hash, constructorCalldata);
  return address;
};

export const setRewardPoolInVeLords = async (veLords, rewardPool) => {
  ///////////////////////////////////////////
  /////  Set Reward Pool in veLords      ////
  ///////////////////////////////////////////

  const account = getAccount();
  console.log(`\n Setting Reward Pool ... \n\n`.green);

  const contract = await account.execute([
    {
      contractAddress: veLords,
      entrypoint: "set_reward_pool",
      calldata: [rewardPool],
    }
  ]);

  // Wait for transaction
  let network = getNetwork(process.env.STARKNET_NETWORK);
  console.log(
    "Tx hash: ".green,
    `${network.explorer_url}/tx/${contract.transaction_hash})`
  );
  await account.waitForTransaction(contract.transaction_hash);

  console.log("Successfully set reward pool in veLords".green, "\n\n");
};


export const setFinalAdminInRewardPoolAndVeLords = async (veLords, rewardPool) => {
  ///////////////////////////////////////////////////////////
  /////  Set Final Admin in Reward Pool and VeLords      ////
  ///////////////////////////////////////////////////////////

  const account = getAccount();
  console.log(`\n Setting Final Admin in Reward Pool and VeLords ... \n\n`.green);
  
  let FINAL_ADMIN = BigInt(process.env.FINAL_ADMIN);
  const contract = await account.execute([
    {
      contractAddress: veLords,
      entrypoint: "transfer_ownership",
      calldata: [FINAL_ADMIN],
    },
    {
      contractAddress: rewardPool,
      entrypoint: "transfer_ownership",
      calldata: [FINAL_ADMIN],
    }
  ]);

  // Wait for transaction
  let network = getNetwork(process.env.STARKNET_NETWORK);
  console.log(
    "Tx hash: ".green,
    `${network.explorer_url}/tx/${contract.transaction_hash})`
  );
  await account.waitForTransaction(contract.transaction_hash);

  console.log(`Successfully set final admin in reward pool and veLords to ${FINAL_ADMIN}`.green, "\n\n");
};
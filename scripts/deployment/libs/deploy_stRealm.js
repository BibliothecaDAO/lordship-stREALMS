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



export const deploy = async (
  DEFAULT_ADMIN,
  MINTER_BURNER,
  UPGRADER,
  FLOW_RATE,
  REWARD_TOKEN,
  REWARD_PAYER
) => {
  ///////////////////////////////////////////
  //////      BRIDE L2 CONTRACT         /////
  ///////////////////////////////////////////

  // Load account
  let name = "strealm";
  const account = getAccount();
  const class_hash = (await declare(getPath(TARGET_PATH, name), name)).class_hash;

  let constructorCalldata = [
    DEFAULT_ADMIN,
    MINTER_BURNER,
    UPGRADER,
    FLOW_RATE,
    0, // u256 high
    REWARD_TOKEN,
    REWARD_PAYER,
  ];

  // Deploy contract
  console.log(`\nDeploying ${name} ... \n\n`.green);
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



export const deployStRealm = async () => {

  let STREALM_DEFAULT_ADMIN =
    0x06a4d4e8c1cc9785e125195a2f8bd4e5b0c7510b19f3e2dd63533524f5687e41n;
  let STREALM_MINTER_BURNER =
    0x06a4d4e8c1cc9785e125195a2f8bd4e5b0c7510b19f3e2dd63533524f5687e41n;
  let STREALM_UPGRADER =
    0x06a4d4e8c1cc9785e125195a2f8bd4e5b0c7510b19f3e2dd63533524f5687e41n;
  let STREALM_FLOW_RATE = 3n * 10n ** 16n;
  let STREALM_REWARD_TOKEN =
    0x04ef0e2993abf44178d3a40f2818828ed1c09cde9009677b7a3323570b4c0f2en;
  let STREALM_REWARD_PAYER =
    0x06a4d4e8c1cc9785e125195a2f8bd4e5b0c7510b19f3e2dd63533524f5687e41n;

  await deploy(
    STREALM_DEFAULT_ADMIN,
    STREALM_MINTER_BURNER,
    STREALM_UPGRADER,
    STREALM_FLOW_RATE,
    STREALM_REWARD_TOKEN,
    STREALM_REWARD_PAYER
  );
};

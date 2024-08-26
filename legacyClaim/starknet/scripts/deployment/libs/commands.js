import "dotenv/config";
import * as path from "path";
import { fileURLToPath } from "url";
import { declare, getContractPath, deploy } from "./common.js";
import { getAccount, getNetwork } from "./network.js";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const TARGET_PATH = path.join(__dirname, "..", "..", "..", "target", "release");



export const deployl2Bridge = async () => {
  ///////////////////////////////////////////
  ////////    LegacyClaim l2 Bridge  ////////
  ///////////////////////////////////////////

  // declare contract
  let casualName = "l2_bridge";
  let projectName = "bridge";
  let contractName = "bridge";
  const class_hash = (
    await declare(getContractPath(TARGET_PATH, projectName, contractName), casualName)
  ).class_hash;

  // deploy contract
  let L2_BRIDGE_ADMIN = BigInt(process.env.L2_BRIDGE_ADMIN);
  let L2_REWARD_TOKEN = BigInt(process.env.L2_REWARD_TOKEN);
  let constructorCalldata = [L2_BRIDGE_ADMIN, L2_REWARD_TOKEN];
  let address = await deploy(casualName, class_hash, constructorCalldata);
  return address;
};





export const setL1BridgeAddressInL2Bridge = async (l2Bridge, l1Bridge) => {
  ///////////////////////////////////////////
  //  Set L1 Bridge Address in L2 Bridge  ///
  ///////////////////////////////////////////

  const account = getAccount();
  console.log(`\n Setting L1 Bridge Address ... \n\n`.green);

  const contract = await account.execute([
    {
      contractAddress: l2Bridge,
      entrypoint: "set_l1_bridge_address",
      calldata: [l1Bridge],
    }
  ]);

  // Wait for transaction
  let network = getNetwork(process.env.STARKNET_NETWORK);
  console.log(
    "Tx hash: ".green,
    `${network.explorer_url}/tx/${contract.transaction_hash})`
  );
  await account.waitForTransaction(contract.transaction_hash);

  console.log(`Successfully set L1 Bridge Address to ${l1Bridge} in L2 Bridge ${l2Bridge}`.green, "\n\n");
};


export const setOwnerAddressInL2Bridge = async (l2Bridge, ownerAddress) => {
  ///////////////////////////////////////////
  //  Set Owner Address in L2 Bridge  ///
  ///////////////////////////////////////////

  const account = getAccount();
  console.log(`\n Setting New Owner Address ... \n\n`.green);

  const contract = await account.execute([
    {
      contractAddress: l2Bridge,
      entrypoint: "transfer_ownership",
      calldata: [ownerAddress],
    },
  ]);

  // Wait for transaction
  let network = getNetwork(process.env.STARKNET_NETWORK);
  console.log(
    "Tx hash: ".green,
    `${network.explorer_url}/tx/${contract.transaction_hash})`
  );
  await account.waitForTransaction(contract.transaction_hash);

  console.log(
    `Successfully set New Owner Address to ${ownerAddress} in L2 Bridge ${l2Bridge}`
      .green,
    "\n\n"
  );
};

import "dotenv/config";
import { getL2DeploymentAddress, getL1DeploymentAddress } from "./common.js";
import { getAccount, getNetwork } from "./network.js";


export const setl2Bridge = async () => {
  ///////////////////////////////////////////
  ////////    Set L2 Bridge Data      ///////
  ///////////////////////////////////////////

  const account = getAccount();
  console.log(`\nUpdating L2 Bridge Contract ... \n\n`.green);

  let l2BridgeAddress = await getL2DeploymentAddress("l2_bridge");

  let l2StrealmAddress = await getL2DeploymentAddress("l2_strealm");
  let l1BridgeAddress = await getL1DeploymentAddress("l1_bridge");

  const contract = await account.execute([
    {
      contractAddress: l2BridgeAddress,
      entrypoint: "set_l1_bridge_address",
      calldata: [l1BridgeAddress],
    },
    {
      contractAddress: l2BridgeAddress,
      entrypoint: "set_l2_token_address",
      calldata: [l2StrealmAddress],
    },
  ]);
  
  // Wait for transaction
  let network = getNetwork(process.env.STARKNET_NETWORK);
  console.log(
    "Tx hash: ".green,
    `${network.explorer_url}/tx/${contract.transaction_hash})`
  );
  await account.waitForTransaction(contract.transaction_hash);
  
  console.log("Successfully updated l2 bridge contract".green, "\n\n");
};

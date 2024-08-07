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
  "starknet",
  "target",
  "release"
);



export const declarel2Bridge = async () => {
  ///////////////////////////////////////////
  ////////    L2 Bridge         /////////////
  ///////////////////////////////////////////
  // declare contract
  let realName = "l2_bridge";
  let contractName = "bridge";
  const class_hash = (
    await declare(getContractPath(TARGET_PATH, contractName), realName)
  ).class_hash;

};

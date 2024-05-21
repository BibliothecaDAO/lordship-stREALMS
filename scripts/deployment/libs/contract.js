import "dotenv/config";
import * as fs from "fs";
import * as path from "path";
import { fileURLToPath } from "url";
import { json } from "starknet";
import { getNetwork, getAccount } from "./network.js";
import { assert } from "console";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const TARGET_PATH = path.join(
  __dirname,
  "..",
  "..",
  "..",
  "contracts",
  "target",
  "release"
);

const getContracts = () => {
  if (!fs.existsSync(TARGET_PATH)) {
    throw new Error(`Target directory not found at path: ${TARGET_PATH}`);
  }
  const contracts = fs
    .readdirSync(TARGET_PATH)
    .filter((contract) => contract.includes(".contract_class.json"));
  if (contracts.length === 0) {
    throw new Error("No build files found. Run `scarb build` first");
  }
  return contracts;
};

const getPath = (contract_name) => {
  const contracts = getContracts();
  const c = contracts.find((contract) => contract.includes(contract_name));
  if (!c) {
    throw new Error(`Contract not found: ${contract_name}`);
  }
  return path.join(TARGET_PATH, c);
};

const declare = async (filepath, contract_name) => {
  console.log(`\nDeclaring ${contract_name}...\n\n`.magenta);
  const compiledSierraCasm = filepath.replace(
    ".contract_class.json",
    ".compiled_contract_class.json"
  );
  const compiledFile = json.parse(fs.readFileSync(filepath).toString("ascii"));
  const compiledSierraCasmFile = json.parse(
    fs.readFileSync(compiledSierraCasm).toString("ascii")
  );
  const account = getAccount();
  const contract = await account.declareIfNot({
    contract: compiledFile,
    casm: compiledSierraCasmFile,
  });

  const network = getNetwork(process.env.STARKNET_NETWORK);
  console.log(`- Class Hash: `.magenta, `${contract.class_hash}`);
  if (contract.transaction_hash) {
    console.log(
      "- Tx Hash: ".magenta,
      `${network.explorer_url}/tx/${contract.transaction_hash})`
    );
    await account.waitForTransaction(contract.transaction_hash);
  } else {
    console.log("- Tx Hash: ".magenta, "Already declared");
  }

  return contract;
};

export const deployLordship = async (
  DEFAULT_ADMIN,
  MINTER_BURNER,
  UPGRADER,
  FLOW_RATE,
  REWARD_TOKEN,
  REWARD_PAYER
) => {
  ///////////////////////////////////////////
  ////////    LORDSHIP         //////////////
  ///////////////////////////////////////////

  // Load account
  const account = getAccount();

  // declare contract
  let name = "Lordship";
  const class_hash = (await declare(getPath(name), name)).class_hash;

  assert(FLOW_RATE <= 2n ** 128n);

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

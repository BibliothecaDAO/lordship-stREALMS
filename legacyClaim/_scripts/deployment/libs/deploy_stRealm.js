import "dotenv/config";
import * as path from "path";
import { fileURLToPath } from "url";
import { declare, deploy, getContractPath, getL2DeploymentAddress } from "./common.js";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const TARGET_PATH = path.join(
  __dirname,
  "..",
  "..",
  "..",
  "stRealms",
  "target",
  "release"
);

export const declareNameAndAttrsMetadata = async () => {
  let name = "metadata_name_and_attrs";
  let contractName = "strealm_NameAndAttrsMetadata";
  const class_hash = (await declare(getContractPath(TARGET_PATH, contractName), name))
    .class_hash;
  return class_hash;
};

export const declareURLPartAMetadata = async () => {
  let name = "metadata_url_part_a";
  let contractName = "strealm_URLPartAMetadata";
  const class_hash = (await declare(getContractPath(TARGET_PATH, contractName), name))
    .class_hash;
  return class_hash;
};

export const declareURLPartBMetadata = async () => {
  let name = "metadata_url_part_b";
  let contractName = "strealm_URLPartBMetadata";
  const class_hash = (await declare(getContractPath(TARGET_PATH, contractName), name))
    .class_hash;
  return class_hash;
};


export const deployRealmMetadata = async () => {
  let name = "l2_realms_metadata";
  let contractName = "strealm_RealmMetadata";


  let nameAndAttrsMetadataClassHash = await declareNameAndAttrsMetadata();
  let urlPartAMetadataClassHash = await declareURLPartAMetadata();
  let urlPartBMetadataClassHash = await declareURLPartBMetadata();

  // Deploy contract
  const class_hash = (await declare(getContractPath(TARGET_PATH, contractName), name))
    .class_hash;
  let constructorCalldata = [
      nameAndAttrsMetadataClassHash,
      urlPartAMetadataClassHash,
      urlPartBMetadataClassHash,
    ]
  let contract_address = await deploy(name, class_hash, constructorCalldata);
  return contract_address;
};



export const deployStRealm = async () => {
  ///////////////////////////////////////////
  //////      StRealm L2 CONTRACT       /////
  ///////////////////////////////////////////

  let STREALM_DEFAULT_ADMIN = BigInt(process.env.STREALM_DEFAULT_ADMIN);
  let STREALM_UPGRADER = BigInt(process.env.STREALM_UPGRADER);
  let STREALM_FLOW_RATE =process.env.STREALM_FLOW_RATE;
  let STREALM_REWARD_TOKEN = BigInt(process.env.STREALM_REWARD_TOKEN);
  let STREALM_REWARD_PAYER = BigInt(process.env.STREALM_REWARD_PAYER);
  const STREALM_METADATA_ADDRESS = await deployRealmMetadata();
  let STREALM_MINTER_BURNER = await getL2DeploymentAddress("l2_bridge");

  // Load account
  let name = "l2_strealm";
  let contractName = "strealm_StRealm";
  const class_hash = (await declare(getContractPath(TARGET_PATH, contractName), name))
    .class_hash;
  let constructorCalldata = [
    STREALM_DEFAULT_ADMIN,
    STREALM_MINTER_BURNER,
    STREALM_UPGRADER,
    STREALM_FLOW_RATE,
    0, // u256 high
    STREALM_REWARD_TOKEN,
    STREALM_REWARD_PAYER,
    STREALM_METADATA_ADDRESS
  ];

  // Deploy contract
  let contract_address = deploy(name, class_hash, constructorCalldata);

};

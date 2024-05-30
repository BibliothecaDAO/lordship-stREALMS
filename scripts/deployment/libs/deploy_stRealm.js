import "dotenv/config";
import * as path from "path";
import { fileURLToPath } from "url";
import { getNetwork, getAccount } from "./network.js";
import { declare, deploy, getPath } from "./common.js";

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
  let name = "NameAndAttrsMetadata";
  let contractName = "strealm_NameAndAttrsMetadata";
  const class_hash = (await declare(getPath(TARGET_PATH, contractName), name))
    .class_hash;
  return class_hash;
};

export const declareURLPartAMetadata = async () => {
  let name = "URLPartAMetadata";
  let contractName = "strealm_URLPartAMetadata";
  const class_hash = (await declare(getPath(TARGET_PATH, contractName), name))
    .class_hash;
  return class_hash;
};

export const declareURLPartBMetadata = async () => {
  let name = "URLPartBMetadata";
  let contractName = "strealm_URLPartBMetadata";
  const class_hash = (await declare(getPath(TARGET_PATH, contractName), name))
    .class_hash;
  return class_hash;
};


export const deployRealmMetadata = async () => {
  let name = "Realm Metadata";
  let contractName = "strealm_RealmMetadata";


  let nameAndAttrsMetadataClassHash = await declareNameAndAttrsMetadata();
  let urlPartAMetadataClassHash = await declareURLPartAMetadata();
  let urlPartBMetadataClassHash = await declareURLPartBMetadata();

  // Deploy contract
  const class_hash = (await declare(getPath(TARGET_PATH, contractName), name))
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
  const STREALM_METADATA_ADDRESS = await deployRealmMetadata();

  // // Load account
  // let name = "strealm";
  // let contractName = "strealm_StRealm";
  // const class_hash = (await declare(getPath(TARGET_PATH, contractName), name))
  //   .class_hash;
  // let constructorCalldata = [
  //   STREALM_DEFAULT_ADMIN,
  //   STREALM_MINTER_BURNER,
  //   STREALM_UPGRADER,
  //   STREALM_FLOW_RATE,
  //   0, // u256 high
  //   STREALM_REWARD_TOKEN,
  //   STREALM_REWARD_PAYER,
  //   STREALM_METADATA_ADDRESS
  // ];

  // Deploy contract
  // let contract_address = deploy(name, class_hash, constructorCalldata);

};

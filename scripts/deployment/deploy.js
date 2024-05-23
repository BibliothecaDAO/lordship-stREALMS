import colors from "colors";
import { deployStRealm } from "./libs/deploy_stRealm.js";
import { deployl2Bridge } from "./libs/deploy_l2bridge.js";

const main = async () => {
  console.log(`   ____          _         `.red);
  console.log(`  |    \\ ___ ___| |___ _ _ `.red);
  console.log(`  |  |  | -_| . | | . | | |`.red);
  console.log(`  |____/|___|  _|_|___|_  |`.red);
  console.log(`            |_|       |___|`.red);

  await deployl2Bridge();
  // await deployStRealm();
};

main();

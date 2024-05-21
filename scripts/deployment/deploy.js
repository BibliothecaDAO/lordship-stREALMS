import colors from "colors";
import { deployLordship } from "./libs/contract.js";

const main = async () => {
  console.log(`   ____          _         `.red);
  console.log(`  |    \\ ___ ___| |___ _ _ `.red);
  console.log(`  |  |  | -_| . | | . | | |`.red);
  console.log(`  |____/|___|  _|_|___|_  |`.red);
  console.log(`            |_|       |___|`.red);

  let LORDSHIP_DEFAULT_ADMIN = 0x11;
  let LORDSHIP_MINTER_BURNER = 0x22;
  let LORDSHIP_UPGRADER = 0x33;
  let LORDSHIP_FLOW_RATE = 3n * 10n ** 18n;
  let LORDSHIP_REWARD_TOKEN = 0x55;
  let LORDSHIP_REWARD_PAYER = 0x66;

  await deployLordship(
    LORDSHIP_DEFAULT_ADMIN,
    LORDSHIP_MINTER_BURNER,
    LORDSHIP_UPGRADER,
    LORDSHIP_FLOW_RATE,
    LORDSHIP_REWARD_TOKEN,
    LORDSHIP_REWARD_PAYER
  );
};

main();

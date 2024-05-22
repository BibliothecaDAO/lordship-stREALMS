import colors from "colors";
import { deployLordship } from "./libs/contract.js";

const main = async () => {
  console.log(`   ____          _         `.red);
  console.log(`  |    \\ ___ ___| |___ _ _ `.red);
  console.log(`  |  |  | -_| . | | . | | |`.red);
  console.log(`  |____/|___|  _|_|___|_  |`.red);
  console.log(`            |_|       |___|`.red);

  let LORDSHIP_DEFAULT_ADMIN = 0x06a4d4e8c1cc9785e125195a2f8bd4e5b0c7510b19f3e2dd63533524f5687e41n;
  let LORDSHIP_MINTER_BURNER = 0x06a4d4e8c1cc9785e125195a2f8bd4e5b0c7510b19f3e2dd63533524f5687e41n;
  let LORDSHIP_UPGRADER = 0x06a4d4e8c1cc9785e125195a2f8bd4e5b0c7510b19f3e2dd63533524f5687e41n;
  let LORDSHIP_FLOW_RATE = 3n * 10n ** 16n;
  let LORDSHIP_REWARD_TOKEN = 0x04ef0e2993abf44178d3a40f2818828ed1c09cde9009677b7a3323570b4c0f2en;
  let LORDSHIP_REWARD_PAYER = 0x06a4d4e8c1cc9785e125195a2f8bd4e5b0c7510b19f3e2dd63533524f5687e41n;

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

import colors from "colors";
import { deployRewardPool, deployVeLords, setRewardPoolInVeLords } from "./libs/deploy.js";

const main = async () => {
  console.log(`   ____          _         `.red);
  console.log(`  |    \\ ___ ___| |___ _ _ `.red);
  console.log(`  |  |  | -_| . | | . | | |`.red);
  console.log(`  |____/|___|  _|_|___|_  |`.red);
  console.log(`            |_|       |___|`.red);


  let veLordsAddress = await deployVeLords();
  let rewardPoolAddress = await deployRewardPool(veLordsAddress);
  await setRewardPoolInVeLords(veLordsAddress, rewardPoolAddress)
};

main();

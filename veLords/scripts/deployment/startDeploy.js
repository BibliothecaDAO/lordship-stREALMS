import colors from "colors";
import { deployLordsBurner, deployRewardPool, deployVeLords, setFinalAdminInRewardPoolAndVeLords, setRewardPoolInVeLords } from "./libs/deploy.js";

const main = async () => {
  console.log(`   ____          _         `.red);
  console.log(`  |    \\ ___ ___| |___ _ _ `.red);
  console.log(`  |  |  | -_| . | | . | | |`.red);
  console.log(`  |____/|___|  _|_|___|_  |`.red);
  console.log(`            |_|       |___|`.red);


  let veLordsAddress = await deployVeLords();
  let rewardPoolAddress = await deployRewardPool(veLordsAddress);
  await deployLordsBurner(rewardPoolAddress);
  await setRewardPoolInVeLords(veLordsAddress, rewardPoolAddress)
  await setFinalAdminInRewardPoolAndVeLords(veLordsAddress, rewardPoolAddress)
};

main();

import colors from "colors";
import { declareRewardPool, declareVeLords } from "./libs/deploy.js";

const main = async () => {
  await declareVeLords();
  await declareRewardPool();
};

main();

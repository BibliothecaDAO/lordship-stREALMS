import "dotenv/config";
import { getNetwork, getAccount } from "./network.js";
import colors from "colors";
import data from "../../../stRealms/scripts/metadata_compressed.json" assert { type: "json" };

const stRealmAddress =
  0x02b80629170ef5d194b661bc2a2cec1ec24acc47d36a40a1f88bf6aee3f986e5n;
export const call = async () => {


  // Load account
  const account = getAccount();
  const end = 5
  const start = 1;
  let cd = [end - start + 1]
  for (let i = start; i <= end; i++) {
    let d = data[i];
    cd.push(i);
    cd = cd.concat(d["serialized"])
  }
  console.log(account)
   
  try {
        let calldata = {
        contractAddress: stRealmAddress,
        entrypoint: "set_uri_data",
        calldata: cd,
        };
        let res = await account.execute(calldata);
        console.log(calldata)
        console.log(res);
    } catch (err) {
        console.log(err);
        console.log("Something went wrong token");
    }  
};

call();

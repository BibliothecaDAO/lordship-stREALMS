const fs = require("fs");
const path = require("path");
const assert = require("assert").strict;
// Define paths to the input and output files
const inputFilePath = path.join(__dirname, "claims.json");
const cairoFileName = "claims.cairo";
const cairoFilePath = path.join(__dirname, "..","..", "starknet", "src", cairoFileName);

// Function to generate mapping function string for Cairo
const generateMappingFunction = (mapping, name) => {
  let functionString = `fn ${name}_mapping(num: felt252) -> (felt252, felt252) {\n    match num {\n`;
  functionString += `        0 => panic!("zero ${name}"), \n`;
  for (const [key, value] of Object.entries(mapping)) {
    functionString += `        ${Number(key) + 1} => (${value.address}, ${value.amount}),\n`;
  }
  functionString += `        _ => panic!("max ${name} num exceeded")\n    }\n}`;
  return functionString;
};


// Read the custom.json file
fs.readFile(inputFilePath, "utf8", (err, data) => {
  if (err) {
    console.error("Error reading the file:", err);
    return;
  }

  // Parse the JSON data
  let jsonData;
  try {
    jsonData = JSON.parse(data);
  } catch (parseErr) {
    console.error("Error parsing JSON data:", parseErr);
    return;
  }

    let generatedCairoFile = generateMappingFunction(jsonData, "claims");
    fs.writeFile(cairoFilePath, generatedCairoFile, (err) => {
      if (err) {
        console.error("Error writing file:", err);
      } else {
        console.log(`File saved successfully as ${cairoFileName}`);
      }
    });
});




  // // generate cairo file to store compressed json 
  // fs.writeFile(
  //   cairoFilePath,
  //   generateCompressDataFunction(jsonData),
  //   "utf8",
  //   (err) => {
  //     if (err) {
  //       console.error("Error writing the file:", err);
  //     } else {
  //       console.log(`Updated data has been saved to ${cairoFilePath}`);
  //     }
  //   }
  // );
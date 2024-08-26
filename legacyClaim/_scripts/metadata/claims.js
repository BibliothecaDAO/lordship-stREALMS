const fs = require("fs");
const csv = require("csv-parse/sync");
const path = require("path");
const claimsVSCFilePath = path.join(__dirname, "claims.csv");
const claimsJSONFilePath = path.join(__dirname, "claims.json");

/////////////////////////////////////////////////
//// convert claims.csv to json
/////////////////////////////////////////////////

// Function to convert decimal to hexadecimal
function decimalToHex(decimal) {
  return "0x" + decimal.toString(16).toUpperCase();
}

// Read the CSV file
const claimsCSVFileContent = fs.readFileSync(claimsVSCFilePath, "utf-8");
// Parse the CSV content
const claimsRecords = csv.parse(claimsCSVFileContent, {
  delimiter: ",",
  skip_empty_lines: true,
});


// Process the claimsRecords and create the output object
const claimsJson = {};
claimsRecords.forEach((record, index) => {
  const [address, amount] = record;
  claimsJson[index] = {
    address: address,
    amount: decimalToHex(BigInt(amount) * BigInt(10 ** 18)),
  };
});

// Convert the output object to a JSON string
const claimsJsonOutput = JSON.stringify(claimsJson, null, 2);
// Write the JSON to a file
fs.writeFileSync(claimsJSONFilePath, claimsJsonOutput);

console.log("\n\n Conversion complete from claims.csv to claims.json \n\n");


/////////////////////////////////////////////////
//// convert claims.json to claims.cairo
/////////////////////////////////////////////////

// Define paths to the input and output files
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


// Read the claims.json file
let generatedCairoFile = generateMappingFunction(claimsJson, "claims");
fs.writeFile(cairoFilePath, generatedCairoFile, (err) => {
  if (err) {
    console.error("Error writing file:", err);
  } else {
    console.log(`File saved successfully as ${cairoFileName}`);
  }
});


console.log("\n\n Conversion complete from claims.json to claims.cairo \n\n");

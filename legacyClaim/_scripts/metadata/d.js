const fs = require("fs");

function generateJSONAndSaveToFile(n, filename) {
  const result = {};
  const sampleData = {
    address: "0xDB65702A9b26f8a643a31a4c84b9392589e03D7c",
    amount: "0xD3C21BCECCEDA1000000",
  };

  for (let i = 0; i < n; i++) {
    result[i] = { ...sampleData };
  }

  const jsonString = JSON.stringify(result, null, 2);

  fs.writeFile(filename, jsonString, (err) => {
    if (err) {
      console.error("Error writing file:", err);
    } else {
      console.log(`File saved successfully as ${filename}`);
    }
  });

  return result;
}

// Example usage:
const numberOfKeys = 3000;
const filename = "output.json";
generateJSONAndSaveToFile(numberOfKeys, filename);

const { assert } = require("console");
const fs = require("fs");
const path = require("path");

// Define paths to the input and output files
const inputFilePath = path.join(__dirname, "metadata_original.json");
const outputFilePath = path.join(__dirname, "metadata_compressed.json");
const cairoFilePath = path.join(__dirname, "..", "src", "metadata.cairo");

// Character map for transliteration to ASCII
const charMap = {
  á: "a",
  ú: "u",
  é: "e",
  ä: "a",
  Š: "S",
  Ï: "I",
  š: "s",
  Í: "I",
  í: "i",
  ó: "o",
  ï: "i",
  ë: "e",
  ê: "e",
  â: "a",
  Ó: "O",
  ü: "u",
  Á: "A",
  Ü: "U",
  ô: "o",
  ž: "z",
  Ê: "E",
  ö: "o",
  č: "c",
  Â: "A",
  Ä: "A",
  Ë: "E",
  É: "E",
  Č: "C",
  Ž: "Z",
  Ö: "O",
  Ú: "U",
  Ô: "O",
  "‘": "'",
};

// Function to move "Wonder" attribute to the last position
const moveWonderToLast = (attributes) => {
  const wonderIndex = attributes.findIndex((attribute) =>
    attribute.trait_type.includes("Wonder")
  );
  if (wonderIndex !== -1) {
    const wonderAttribute = attributes.splice(wonderIndex, 1)[0];
    attributes.push(wonderAttribute);
  } else {
    attributes.push({
      trait_type: "Wonder (translated)",
      value: "None",
    });
  }
  return attributes;
};

// Function to generate mapping function string for Cairo
const generateMappingFunction = (mapping, name) => {
  let functionString = `fn ${name}_mapping(num: felt252) -> ByteArray {\n    match num {\n`;
  functionString += `        0 => panic!("zero ${name}"), \n`;
  for (const [key, value] of Object.entries(mapping)) {
    functionString += `        ${value} => "${key}",\n`;
  }
  functionString += `        _ => panic!("max ${name} num exceeded")\n    }\n}`;
  return functionString;
};

// Function to generate mapping function string for Cairo
const generateCompressDataFunction = (jsonData) => {
  let functionString = `fn compressed_metadata(token_id: felt252) -> felt252 {\n    match token_id {\n`;
  functionString += `        0 => panic!("zero token id"), \n`;
  for (const [key, value] of Object.entries(jsonData)) {
    functionString += `        ${key} => ${value["serialized"]},\n`;
  }
  functionString += `        _ => panic!("max token id exceeded")\n    }\n}`;
  return functionString;
};

// Function to transliterate a string to ASCII
const transliterate = (str) => {
  return str
    .split("")
    .map((char) => charMap[char] || char)
    .join("");
};

// Function to serialize a string to byte array
const serializeStrToByteArray = (str, arr) => {
  let pending_word_len = 0;
  arr.push(Math.floor(str.length / 31));
  while (str.length > 0) {
    if (str.length < 31) {
      pending_word_len = str.length;
    }
    arr.push(strToFeltArr(str.slice(0, 31))[0]);
    str = str.slice(31);
  }
  arr.push(pending_word_len);
};

// Function to convert string to felt array
const strToFeltArr = (str) => {
  const size = Math.ceil(str.length / 31);
  const arr = Array(size);
  let offset = 0;
  for (let i = 0; i < size; i++) {
    const substr = str.substring(offset, offset + 31).split("");
    const ss = substr.reduce(
      (memo, c) => memo + c.charCodeAt(0).toString(16),
      ""
    );
    arr[i] = `0x${ss.toString(16)}`;
    offset += 31;
  }
  return arr;
};

// Function to convert array to U256
const numArrayToEncodedU256 = (arr) => {
  if (arr.length > 32) {
    throw new Error("Array length exceeds the maximum allowed length of 32");
  }
  let u256 = BigInt(0);
  for (let i = 0; i < arr.length; i++) {
    if (arr[i] < 0 || arr[i] > 255) {
      throw new Error("Array contains values outside of the u8 range");
    }
    u256 |= BigInt(arr[i]) << BigInt(i * 8);
  }
  return `0x${u256.toString(16)}`;
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

  // Process each item to move "Wonder" attribute to the last position
  for (const key in jsonData) {
    if (jsonData.hasOwnProperty(key)) {
      jsonData[key].attributes = moveWonderToLast(jsonData[key].attributes);
    }
  }

  // Collect unique Resource, Order, and Wonder values
  const resourceSet = new Set();
  const orderSet = new Set();
  const wonderSet = new Set();
  for (const key in jsonData) {
    const attributes = jsonData[key].attributes;
    attributes.forEach((attribute) => {
      if (attribute.trait_type === "Resource") {
        resourceSet.add(attribute.value);
      } else if (attribute.trait_type === "Order") {
        orderSet.add(attribute.value);
      } else if (attribute.trait_type.includes("Wonder")) {
        wonderSet.add(attribute.value);
      }
    });
  }

  // Assign numbers to unique Resource values
  const resourceArray = Array.from(resourceSet);
  const resourceMap = {};
  resourceArray.forEach((resource, index) => {
    resourceMap[resource] = index + 1;
  });

  // Print the resource mapping
  console.log("\n\nResource Mapping:", resourceMap, "\n\n");

  // Assign numbers to unique Order values
  const orderArray = Array.from(orderSet);
  const orderMap = {};
  orderArray.forEach((order, index) => {
    orderMap[order] = index + 1;
  });

  // Print the order mapping
  console.log("\n\nOrder Mapping:", orderMap, "\n\n");

  // Assign numbers to unique Wonder values
  const wonderArray = Array.from(wonderSet);
  const wonderMap = {};
  wonderArray.forEach((wonder, index) => {
    wonderMap[wonder] = index + 1;
  });

  // Print the wonder mapping
  console.log("\n\nWonder Mapping:", wonderMap, "\n\n");

  // Update the JSON data with Resource, Order, and Wonder numbers and convert attributes to values
  for (const key in jsonData) {
    const attributes = jsonData[key].attributes;

    // Replace trait_type values with numbers
    attributes.forEach((attribute) => {
      if (attribute.trait_type === "Resource") {
        attribute.value = resourceMap[attribute.value];
      } else if (attribute.trait_type === "Order") {
        attribute.value = orderMap[attribute.value];
      } else if (attribute.trait_type.includes("Wonder")) {
        attribute.value = wonderMap[attribute.value];
      }
    });

    // Convert attributes array from an array of objects to an array of values
    jsonData[key].attributes = attributes.map((attribute) => attribute.value);
  }

  // Update the JSON data to convert all values to arrays
  for (const key in jsonData) {
    const item = jsonData[key];
    const newArray = [];
    for (const prop in item) {
      if (Array.isArray(item[prop])) {
        item[prop].forEach((value) => newArray.push(value));
      } else {
        newArray.push(item[prop]);
      }
    }
    jsonData[key] = newArray;
  }

  let max_name_len = 12;
  let max_attrs_len = 13;

  // Serialize data for Cairo
  for (const key in jsonData) {
    const item = jsonData[key];

    let name = item.shift();
    let name_felt = strToFeltArr(name)[0];
    assert(name.length <= max_name_len);

    // remove url. var unused
    let _ = item.shift();

    // the remaining items are attrs
    let attrs_len = item.length;
    let attrs_felt = numArrayToEncodedU256(item);
    assert(attrs_len <= max_attrs_len);

    // final felt should be the compress (name, attrs,name.length, attrs_len) which
    // should have maximum bytes of (max_name_len,max_attrs_len,1,1)

    let final_felt =
      (((((BigInt(name_felt) << BigInt(attrs_len * 8)) | BigInt(attrs_felt)) <<
        BigInt(8)) |
        BigInt(name.length)) <<
        BigInt(8)) |
      BigInt(attrs_len);
    final_felt = `0x${final_felt.toString(16)}`;

    jsonData[key] = {
      deserialized: [transliterate(name), attrs_felt],
      serialized: [final_felt],
    };
  }

  // Print the generated mapping functions
  console.log(`\n\n\n ${generateMappingFunction(orderMap, "order")}`);
  console.log(`\n\n\n ${generateMappingFunction(wonderMap, "wonder")}`);
  console.log(`\n\n\n ${generateMappingFunction(resourceMap, "resource")}`);
  console.log(
    `\nmax name len is ${max_name_len} and max attrs len is ${max_attrs_len} so ${max_name_len} + ${max_attrs_len} + 1(name length) + 1(attrs length) = ${
      1 + 1 + max_attrs_len + max_name_len
    } and that's less than 32 . This means both can fit in a single felt\n\n`
  );

  // Save the updated JSON data to output file path
  fs.writeFile(
    outputFilePath,
    JSON.stringify(jsonData, null, 2),
    "utf8",
    (err) => {
      if (err) {
        console.error("Error writing the file:", err);
      } else {
        console.log(`Updated data has been saved to ${outputFilePath}`);
      }
    }
  );

  // generate cairo file to store compressed json 
  fs.writeFile(
    cairoFilePath,
    generateCompressDataFunction(jsonData),
    "utf8",
    (err) => {
      if (err) {
        console.error("Error writing the file:", err);
      } else {
        console.log(`Updated data has been saved to ${cairoFilePath}`);
      }
    }
  );
});
// "‘illo‘‘i‘‘i‘";
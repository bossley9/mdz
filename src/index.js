const modPromise = WebAssembly.instantiateStreaming(
  fetch("rmd.wasm"),
);

const errorPrefix = "error.";

/**
 * Given a RMD input string, parse and return the corresponding HTML
 * string. Errors can be thrown.
 * @param {string} input
 * @returns {Promise<string>} output
 */
export async function parseRMD(input) {
  const wasmMod = await modPromise;
  const memory = wasmMod.instance.exports.memory;
  const parseRMDWasm = wasmMod.instance.exports.parseRMDWasm;

  // encode input into memory
  const memoryArr = new Uint8Array(memory.buffer);
  const { written: inputLength } = new TextEncoder().encodeInto(
    input,
    memoryArr,
  );

  const outputLength = parseRMDWasm(0, inputLength);

  // decode output from memory
  const outputArr = new Uint8Array(memory.buffer, 0, outputLength);
  const output = new TextDecoder().decode(outputArr);

  if (output.startsWith(errorPrefix)) {
    throw new Error(output.substring(errorPrefix.length));
  }

  return output;
}

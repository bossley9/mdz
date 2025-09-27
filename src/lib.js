/* @ts-self-types="./index.d.ts" */

let wasmMod;

/**
 * Given an MDZ input string, parse and return the corresponding HTML
 * string. Errors can be thrown.
 * @param {string} input
 * @return {Promise<string>} output
 */
export async function parseMDZ(input) {
  if (!wasmMod) {
    wasmMod = await WebAssembly.instantiate(
      Uint8Array.from([/*generated_code_flag_marker*/]),
    );
  }
  const { memory, parseMDZWasm } = wasmMod.instance.exports;

  const memoryArr = new Uint8Array(memory.buffer);
  const { written: inputLen } = new TextEncoder().encodeInto(input, memoryArr);

  const outputLen = parseMDZWasm(0, inputLen);

  const outputArr = new Uint8Array(memory.buffer, 0, outputLen);
  const output = new TextDecoder().decode(outputArr);

  if (output.startsWith("error.")) {
    throw new Error(output.substring(6));
  }

  return output;
}

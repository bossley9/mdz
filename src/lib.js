/* @ts-self-types="./index.d.ts" */

let wasmMod;

/**
 * Given a RMD input string, parse and return the corresponding HTML
 * string. Errors can be thrown.
 * @param {string} input
 * @return {Promise<string>} output
 */
export async function parseRMD(input) {
  if (!wasmMod) {
    wasmMod = await WebAssembly.instantiate(
      Uint8Array.from([/*generated_code_flag_marker*/]),
    );
  }
  const { memory, parseRMDWasm } = wasmMod.instance.exports;

  const memoryArr = new Uint8Array(memory.buffer);
  const { written: inputLen } = new TextEncoder().encodeInto(input, memoryArr);

  const outputLen = parseRMDWasm(0, inputLen);

  const outputArr = new Uint8Array(memory.buffer, 0, outputLen);
  const output = new TextDecoder().decode(outputArr);

  if (output.startsWith("error.")) {
    throw new Error(output.substring(6));
  }

  return output;
}

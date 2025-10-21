/* @ts-self-types="./index.d.ts" */

const wasmStr = atob("/*generated_code_flag_marker*/");
const wasmBuf = new Uint8Array(wasmStr.length);
for (let i = 0; i < wasmStr.length; i++) {
  wasmBuf[i] = wasmStr.charCodeAt(i);
}
const wasmMod = WebAssembly.instantiate(wasmBuf);

/**
 * Given an MDZ input string, parse and return the corresponding HTML
 * string. Errors can be thrown.
 * @param {string} input
 * @return {Promise<string>} output
 */
export async function parseMDZ(input) {
  const { memory, parseMDZWasm } = (await wasmMod).instance.exports;

  const memoryArr = new Uint8Array(memory.buffer);
  const { written: inputLen } = new TextEncoder().encodeInto(input, memoryArr);

  const outputLen = parseMDZWasm(0, inputLen);

  const outputArr = new Uint8Array(memory.buffer, 0, outputLen);
  const output = new TextDecoder().decode(outputArr);

  // data can be written to std.io.Writer before an error occurs
  if (/error\.\w+$/.test(output)) {
    const index = output.lastIndexOf("error.") + 6;
    throw new Error(output.substring(index));
  }
  return output;
}

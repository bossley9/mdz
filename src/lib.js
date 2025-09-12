/**
 * @type {WebAssembly.WebAssemblyInstantiatedSource}
 */
let wasmMod;

/**
 * Given a RMD input string, parse and return the corresponding HTML
 * string. Errors can be thrown.
 * @param {string} input
 * @return {Promise<string>} output
 */
export async function parseRMD(input) {
  // unavoidable init time penalty
  if (!wasmMod) {
    wasmMod = await WebAssembly.instantiate(
      // generated_code_flag_marker
    );
  }
  /**
   * @type {WebAssembly.Memory}
   */
  const memory = wasmMod.instance.exports.memory;
  /**
   * @type {(addr: number, len: number) => number}
   */
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

  if (output.startsWith("error.")) {
    throw new Error(output.substring(6));
  }

  return output;
}

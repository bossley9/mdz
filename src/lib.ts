const modPromise = WebAssembly.instantiateStreaming(
  new Response(await Deno.readFile("./zig-out/bin/rmd.wasm"), {
    headers: { "Content-type": "application/wasm" },
  }),
);

/**
 * Given a RMD input string, parse and return the corresponding HTML
 * string. Errors can be thrown.
 */
export async function parseRMD(input: string): Promise<string> {
  const wasmMod = await modPromise;
  const memory = wasmMod.instance.exports.memory as WebAssembly.Memory;
  const parseRMDWasm = wasmMod.instance.exports.parseRMDWasm as (
    inputAddr: number,
    inputLen: number,
  ) => number;

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

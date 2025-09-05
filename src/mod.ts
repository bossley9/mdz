// replace this with fetch() on a server
const source = new Response(
  await Deno.readFile("./zig-out/bin/zigjot.wasm"),
  { headers: { "Content-type": "application/wasm" } },
);
const wasmMod = await WebAssembly.instantiateStreaming(source);

type ParseDjot = (startingMemAddr: 0, memoryLen: number) => number;

const errorPrefix = "error.";

/**
 * Given a Djot input string, parse and return the corresponding HTML
 * string. Errors can be thrown.
 */
export function parseDjot(input: string) {
  const memory = wasmMod.instance.exports.memory as WebAssembly.Memory;
  const parseDjotWasm = wasmMod.instance.exports.parseDjotWasm as ParseDjot;

  // encode input into memory
  const memoryArr = new Uint8Array(memory.buffer);
  const { written: inputLength } = new TextEncoder().encodeInto(
    input,
    memoryArr,
  );

  const outputLength = parseDjotWasm(0, inputLength);

  // decode output from memory
  const outputArr = new Uint8Array(memory.buffer, 0, outputLength);
  const output = new TextDecoder().decode(outputArr);

  if (output.startsWith(errorPrefix)) {
    throw new Error(output.substring(errorPrefix.length));
  }

  return output;
}

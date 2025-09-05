import { parseDjot } from "./mod.ts";

function expectParseDjot(input: string, expected: string) {
  const received = parseDjot(input);
  if (received !== expected) {
    throw new Error(`Expected \n'${expected}'\n but received \n'${received}'`);
  }
}

Deno.test("instantiates the WASM module from JS", () => {
  const input = "Hello, world!";
  const expected = "Line: Hello, world!\n";
  expectParseDjot(input, expected);
});

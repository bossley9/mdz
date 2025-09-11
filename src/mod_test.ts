import { parseRMD } from "./mod.ts";

function expectParseRMD(input: string, expected: string) {
  const received = parseRMD(input);
  if (received !== expected) {
    throw new Error(`Expected \n'${expected}'\n but received \n'${received}'`);
  }
}

Deno.test("instantiates the WASM module from JS", () => {
  const input = "Hello, world!";
  const expected = "<p>Hello, world!</p>";
  expectParseRMD(input, expected);
});

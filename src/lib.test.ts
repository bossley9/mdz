// this test file validates build output directly
import { parseRMD } from "../dist/index.js";

async function expectParseRMD(input: string, expected: string) {
  const received = await parseRMD(input);
  if (received !== expected) {
    throw new Error(`Expected \n'${expected}'\n but received \n'${received}'`);
  }
}

Deno.test("instantiates the WASM module from JS", async () => {
  const input = "Hello, world!";
  const expected = "<p>Hello, world!</p>";
  await expectParseRMD(input, expected);
});

Deno.test("returns empty inputs", async () => {
  await expectParseRMD("", "");
});

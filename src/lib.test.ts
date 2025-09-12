import { parseRMD } from "./lib.ts";

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

// this test file validates build output directly
import { parseMDZ, slugify } from "../../dist/index.js";

async function expectParseMDZ(input: string, expected: string) {
  const received = await parseMDZ(input);
  if (received !== expected) {
    throw new Error(`Expected \n'${expected}'\nbut received\n'${received}'`);
  }
}

Deno.test("instantiates the WASM module from JS", async () => {
  const input = "Hello, world!";
  const expected = "<p>Hello, world!</p>";
  await expectParseMDZ(input, expected);
});

Deno.test("returns empty inputs", async () => {
  await expectParseMDZ("", "");
});

Deno.test("throws errors passed through from Zig", async () => {
  const input = "[invalid link syntax]";
  await parseMDZ(input).then(() => {
    throw new Error(`Expected \n'${input}'\nto throw`);
  }).catch((e) => {
    const expected = "InvalidMDZSyntax";
    if (e.message !== expected) {
      throw new Error(
        `Expected \n'${input}'\nto throw with message '${expected}', but received\n${e.message}`,
      );
    }
  });
});

Deno.test("slugifies a string", async () => {
  const input = "Hello friend! Welcome :)";
  const expected = "hello-friend-welcome";
  const received = await slugify(input);
  if (received !== expected) {
    throw new Error(`Expected \n'${expected}'\nbut received\n'${received}'`);
  }
});

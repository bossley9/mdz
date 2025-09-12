async function expectParseRMD(input: string, expected: string) {
  const globalFetch = globalThis.fetch;
  globalThis.fetch = async () =>
    new Response(
      await Deno.readFile("./zig-out/bin/rmd.wasm"),
      { headers: { "Content-type": "application/wasm" } },
    );
  const mod = await import(`./index.js?t=${Date.now()}`);
  const received = await mod.parseRMD(input);
  if (received !== expected) {
    throw new Error(`Expected \n'${expected}'\n but received \n'${received}'`);
  }
  globalThis.fetch = globalFetch;
}

Deno.test("instantiates the WASM module from JS", async () => {
  const input = "Hello, world!";
  const expected = "<p>Hello, world!</p>";
  await expectParseRMD(input, expected);
});

Deno.test("returns empty inputs", async () => {
  await expectParseRMD("", "");
});

const in_dir = "./src/wasm";
const out_dir = "./dist";
const marker = "/*generated_code_flag_marker*/";

await Deno.mkdir(out_dir).catch(() => {}); // ignore if already exists

// binary generation

await Deno.copyFile(`${in_dir}/index.d.ts`, `${out_dir}/index.d.ts`);

const src = (await Deno.readTextFile(`${in_dir}/index.js`))
  .replace(/\/\/.*/g, ""); // remove line comments
const wasmBuf = await Deno.readFile("./zig-out/bin/mdz.wasm");
let wasmStr = "";
for (const byte of wasmBuf) {
  // cannot apply entire buffer at once or call stack is exceeded
  wasmStr += String.fromCharCode(byte);
}
const wasm = btoa(wasmStr);

const output = src.substring(0, src.indexOf(marker)) +
  wasm +
  src.substring(src.indexOf(marker) + marker.length);

await Deno.writeTextFile(`${out_dir}/index.js`, output);

// documentation generation

const doc = await Deno.readTextFile("./src/mdz/specification.zig");

const generatedDoc = doc
  .split("\n")
  .map((line) => {
    if (
      line.includes("th.expectParseMDZ(") || line.includes("const th = @import")
    ) {
      return null;
    } else if (line.startsWith("//")) {
      return line.substring(line.startsWith("// ") ? 3 : 2);
    } else {
      return line;
    }
  })
  .filter((line) => line !== null)
  .join("\n");

await Deno.writeTextFile("./README.md", generatedDoc);

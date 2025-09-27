// binary generation

await new Deno.Command("zig", { args: ["build", "wasm"] }).output();

await Deno.mkdir("./dist").catch(() => {}); // ignore if already exists

await Deno.copyFile("./src/lib.d.ts", "./dist/index.d.ts");

const marker = "/*generated_code_flag_marker*/";

const src = await Deno.readTextFile("./src/lib.js");
const wasm = await Deno.readFile("./zig-out/bin/mdz.wasm");

const output = src.substring(0, src.indexOf(marker)) +
  wasm +
  src.substring(src.indexOf(marker) + marker.length);

await Deno.writeTextFile("./dist/index.js", output);

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

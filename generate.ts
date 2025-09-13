await new Deno.Command("zig", { args: ["build", "wasm"] }).output();

await Deno.mkdir("./dist").catch(() => {}); // ignore if already exists

const marker = "/*generated_code_flag_marker*/";

const src = await Deno.readTextFile("./src/lib.ts");

const wasm = await Deno.readFile("./zig-out/bin/rmd.wasm");

const output = src.substring(0, src.indexOf(marker)) +
  wasm +
  src.substring(src.indexOf(marker) + marker.length);

await Deno.writeTextFile("./dist/index.ts", output);

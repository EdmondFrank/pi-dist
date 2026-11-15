#!/usr/bin/env bun
// Rewrite build artifacts so pi's findPackageJSON() calls work under Bun.
//
// pi's server chunks call module.findPackageJSON() (Node >= 22.14) to locate
// @earendil-works/pi-coding-agent and the pi-mcp runtime. Bun has no such
// function, so pi-web logs
//   "[pi-web] MCP is off: cannot locate @earendil-works/pi-coding-agent"
// and the builtin llama.cpp provider fails to load.
//
// A --preload shim cannot cover this: pi-web's CLI spawns the Next server as a
// child process, and the chunk reaches node:module through an ESM namespace
// object, which Bun keeps non-extensible. Rewriting the call sites does work.
//
// Usage: bun scripts/patch-find-package-json.mjs [app-dir]
import { readdirSync, readFileSync, statSync, writeFileSync } from "node:fs";
import { join, dirname } from "node:path";
import { fileURLToPath } from "node:url";

const appDir = process.argv[2] ?? join(dirname(fileURLToPath(import.meta.url)), "..");
const serverDir = join(appDir, ".next", "server");
const CALL = /\(0,\s*([A-Za-z_$][\w$]*)\.findPackageJSON\)/g;
const MARKER = "/* pi-dist: module.findPackageJSON for Bun */";

const PRELUDE_CJS = `${MARKER}
var __pdFs = require("node:fs");
var __pdPath = require("node:path");
var __pdUrl = require("node:url");
var __pdModule = require("node:module");
function __piDistFindPackageJSON(specifier, parentUrl) {
  try {
    var req = __pdModule.createRequire(
      parentUrl ? __pdUrl.fileURLToPath(parentUrl) : __pdPath.join(process.cwd(), "index.js"),
    );
    // pi's packages ship only an "import" condition, so require.resolve() on the
    // bare specifier fails; the package.json subpath resolves and is what
    // findPackageJSON() returns anyway.
    try {
      return req.resolve(specifier + "/package.json");
    } catch {}
    var dir = req.resolve(specifier);
    for (;;) {
      var st = __pdFs.statSync(dir, { throwIfNoEntry: false });
      if (st && st.isFile()) dir = __pdPath.dirname(dir);
      var candidate = __pdPath.join(dir, "package.json");
      if (__pdFs.existsSync(candidate)) return candidate;
      var parent = __pdPath.dirname(dir);
      if (parent === dir) return undefined;
      dir = parent;
    }
  } catch {
    return undefined;
  }
}
`;

const PRELUDE_ESM = PRELUDE_CJS.replace(
  /var __pd(Fs|Path|Url|Module) = require\("node:(\w+)"\);/g,
  (_m, name, mod) => `import __pd${name} from "node:${mod}";`,
);

function walk(dir, out = []) {
  for (const name of readdirSync(dir)) {
    const path = join(dir, name);
    if (statSync(path).isDirectory()) walk(path, out);
    else if (name.endsWith(".js")) out.push(path);
  }
  return out;
}

let patched = 0;
for (const file of walk(serverDir)) {
  const source = readFileSync(file, "utf8");
  if (source.includes(MARKER)) continue;
  CALL.lastIndex = 0;
  if (!CALL.test(source)) continue;
  CALL.lastIndex = 0;
  // Webpack emits CommonJS for server chunks; guard anyway.
  const isCjs = /(^|\n)\s*"?use strict"?;?\s*exports\./.test(source) || source.includes("exports.modules=");
  const body = source.replace(CALL, "__piDistFindPackageJSON");
  writeFileSync(file, (isCjs ? PRELUDE_CJS : PRELUDE_ESM) + body);
  patched += 1;
  console.log(`patched ${file} (${isCjs ? "cjs" : "esm"})`);
}
console.log(patched ? `done: ${patched} chunk(s)` : "done: nothing to patch");
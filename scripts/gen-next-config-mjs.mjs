#!/usr/bin/env bun
// Regenerate next.config.mjs from next.config.ts.
//
// Next.js loads a .ts config through require.extensions hooks (it compiles the
// file to CommonJS in memory). Bun does not implement require.extensions, so
// the config fails with "Unexpected token '{'. import call expects one or two
// arguments." Generating a plain .mjs keeps a single source of truth: edit
// next.config.ts, then run this (scripts/pi-web-bun-build.sh does it for you).
import { readFileSync, writeFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const dir = process.argv[2] ?? join(dirname(fileURLToPath(import.meta.url)), "..");
const source = readFileSync(join(dir, "next.config.ts"), "utf8");

const result = source
  // Type-only import and annotations have no runtime meaning.
  .replace(/^import type .*$/gm, "")
  .replace(/\bas \{ version: string \}/g, "")
  .replace(/: NextConfig\b/g, "")
  .replace(/\bas const\b/g, "")
  .replace(/^(\s*const [A-Za-z_$][\w$]*)\s*:\s*[A-Za-z_$][\w$<>[\]]*\s*=/gm, "$1 =");

if (/\b(interface|type)\s+[A-Z]/.test(result) || /:\s*NextConfig/.test(result)) {
  console.error("next.config.ts uses TypeScript syntax this generator cannot strip.");
  console.error("Add the construct to scripts/gen-next-config-mjs.mjs before building.");
  process.exit(1);
}

writeFileSync(
  join(dir, "next.config.mjs"),
  `// Generated from next.config.ts by scripts/gen-next-config-mjs.mjs.\n` +
    `// Edit next.config.ts instead; Bun cannot load a TypeScript Next config.\n` +
    result,
);
console.log("wrote next.config.mjs");
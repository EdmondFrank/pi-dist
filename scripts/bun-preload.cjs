// Bun compatibility shim for pi-web.
//
// Bun implements most of node:module but not findPackageJSON() (Node >= 22.14),
// which pi's server chunks call to locate @earendil-works/pi-coding-agent and
// the pi-mcp runtime. Without it the server logs
//   "[pi-web] MCP is off: cannot locate @earendil-works/pi-coding-agent"
// and the builtin llama.cpp provider fails to load.
//
// Bun's require("node:module") object is extensible, so patching it here (before
// any app code runs) is enough; pi's bundled chunks obtain it through require.
const fs = require("node:fs");
const path = require("node:path");
const url = require("node:url");
const mod = require("node:module");

if (typeof mod.findPackageJSON !== "function") {
  mod.findPackageJSON = function findPackageJSON(specifier, parentUrl) {
    try {
      const referrer = parentUrl
        ? url.fileURLToPath(parentUrl)
        : path.join(process.cwd(), "index.js");
      const req = mod.createRequire(referrer);
      // Packages that ship only an `import` condition (pi's do) cannot be
      // resolved by CJS require(), but their package.json subpath can.
      try {
        return req.resolve(`${specifier}/package.json`);
      } catch { /* fall through to entry resolution */ }
      const stat0 = fs.statSync(req.resolve(specifier), { throwIfNoEntry: false });
      if (stat0 && stat0.isFile() && specifier.endsWith("package.json")) {
        return req.resolve(specifier);
      }
      let dir = req.resolve(specifier);
      for (;;) {
        const stat = fs.statSync(dir, { throwIfNoEntry: false });
        if (stat && stat.isFile()) dir = path.dirname(dir);
        const candidate = path.join(dir, "package.json");
        if (fs.existsSync(candidate)) return candidate;
        const parent = path.dirname(dir);
        if (parent === dir) return undefined;
        dir = parent;
      }
    } catch {
      return undefined;
    }
  };
  if (process.env.PI_WEB_BUN_DEBUG) {
    console.log("[bun-shim] module.findPackageJSON polyfilled");
  }
}
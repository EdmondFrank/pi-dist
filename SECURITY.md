# Security

## Reporting

Open a private [security advisory](https://github.com/EdmondFrank/pi-dist/security/advisories/new)
for anything exploitable. Do not open a public issue first.

## What this repository contains

- **No credentials.** `config/models.json.tmpl` and `config/mcp.json.tmpl` hold
  `${...}` placeholders only; `install.sh` substitutes them locally and writes
  `models.json` / `mcp.json` with mode `0600`.
- **No binaries or vendored sources.** `out/`, `release/`, and `src/` are
  gitignored; releases are compiled per platform.

## Handling keys

- Prefer `"apiKey": "$EXHUB_API_KEY"` in `models.json`: pi interpolates the
  environment variable at runtime, so the secret never lands on disk.
- `mcp.json` `headers` support the same `${VAR}` interpolation (and `!command`
  output), so tokens can stay in the environment too.
- `$PI_CODING_AGENT_DIR` holds `models.json`, `mcp.json`, `auth.json`, and
  session logs — never commit that directory.
- The produced binary embeds the Bun runtime plus pi. Report vulnerabilities in
  either upstream; this repository only contains packaging and configuration.

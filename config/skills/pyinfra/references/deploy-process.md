# How pyinfra Works — Deploy Process

Source: docs.pyinfra.com/en/3.x/deploy-process.html, using-operations.html. pyinfra is "a translator": your deploy Python runs **locally**, once per host; operations become shell commands shipped over the connection. Nothing of your deploy code runs on the target.

## The five stages of every run

1. **Setup** — load inventory file and any group/host data.
2. **Connect** — open one connection per target (e.g. one SSH session). Connection stays open for the whole run; individual operations/facts open *channels* over it, not new sessions.
3. **Prepare** — run deploy code once per host: gather facts, establish operation order, detect which operations will change which hosts. Only read-only commands are sent here.
4. **Execute** — walk operations in order; for each, **re-evaluate** the operation per host to generate its commands, run them on all hosts that need them **in parallel**, wait, then move to the next operation.
5. **Disconnect** — close connections, print the results report.

## Phase 1: prepare (per operation)

When your code calls e.g. `apt.packages(...)`, pyinfra:

1. Reads current state by gathering the facts the operation needs (e.g. `AptPackages`) — read-only shell commands, results **cached for the rest of the deploy**.
2. Diffs that state against your desired state.
3. Advances the operation just far enough to see its *first* command to decide "would change anything" — it does **not** build/keep the full command list. Commands are generated at execute time.
4. Returns an `OperationMeta` handle with `will_change`.

Output of prepare = an **ordering**, not a stored plan. `--debug-operations`/`--dry` therefore report *which ops change which hosts*, never the literal commands (use `-vv` during a real run to see those).

## Phase 2: execute & ordering guarantees

pyinfra stitches per-host orderings into one global sequence and runs each operation in **lock-step across hosts**: all hosts finish (or fail) operation N before any host starts N+1. Example — inventory `web_servers=[web-01..03]`, `db_server=[db-01]` and a deploy that installs a base package for everyone, then group-conditional packages:

```
- "Install base debugging packages" on web-01, web-02, web-03, db-01 (parallel)
- "Install postgres server"         on db-01
- "Install nginx"                   on web-01, web-02, web-03 (parallel)
```

That global sequence is exactly why deploy code must fully run first (prepare) — hence **deploy code always runs before any host is mutated**.

## Implication 1 — branching on facts

Bad (fact reflects pre-deploy state, branch resolves during prepare):

```python
apt.packages(name="Install nginx", packages=["nginx"])
if host.get_fact(File, path="/etc/nginx/sites-enabled/default"):   # False NOW
    files.file(path="/etc/nginx/sites-enabled/default", present=False)
```

Good — state-describing, no branch; pyinfra diffs at execute time:

```python
apt.packages(name="Install nginx", packages=["nginx"])
files.file(name="Remove nginx default site",
           path="/etc/nginx/sites-enabled/default", present=False)
```

Rule from docs: **only branch on immutable facts** (OS family, distro, architecture, kernel). "Is package installed / does file exist / is service running" are mutable — an earlier operation could flip them; use `_if`.

## Implication 2 — branching on operation changes

`if remove_default_site.changed:` in deploy code is always False (prepare time). Use the execute-time gate:

```python
remove_default_site = files.file(..., present=False)
server.service(name="Reload nginx", service="nginx", reloaded=True,
               _if=remove_default_site.did_change)
```

OperationMeta gating callables: `did_change`, `did_not_change`, `did_succeed`, `did_error`; combinators `any_changed(...)` / `all_changed(...)` from `pyinfra.operations.util`. See `writing-deploys.md` for full `_if` semantics.

## Loops & cycle errors

In CLI mode pyinfra builds a single DAG for operation order. A plain Python loop containing operations can make per-host paths disagree (op A before B on one host, B before A on another) → **cycle error** at prepare. Fix: wrap the iterable in `host.loop` so the loop position becomes part of the operation ordering hint:

```python
from pyinfra import host
for i in host.loop(range(0, 2)):
    server.shell(name=f"Do a thing {i}", commands="ls")
```

Worked example from docs: loop where `"A"` only runs on `@local` when `i == 0` produces `@local: A→B→A-1→B-1` vs `other: B→A→B-1` → cycle; with `host.loop` the graph resolves consistently (`0A→0B→1A→1B`).

## Output & why callbacks exist

Because commands are generated at execute time and hosts run concurrently:

- `result.stdout` on an `OperationMeta` raises if read in deploy code (prepare phase).
- To consume output, schedule a `python.call(callback)` — callbacks run at execute time and may themselves call operations (those execute immediately, out of the normal deferred flow).
- Stepping through a deploy in a debugger does not reflect real remote ordering; use facts + `--dry` instead (see `troubleshooting.md`).

## Connection lifecycle summary

Connect (stage 2) → fact reads via channels (stage 3) → command channels per operation (stage 4) → disconnect (stage 5). One SSH session per host per deploy, hence: long-running deploys keep that session; there is no agent to install on targets — the only target requirement is shell access (POSIX where possible; `server`/`files` ops are broadly portable).

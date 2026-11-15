# Cheatsheet — Decision Rules, Thresholds, Tells

Source: distilled across *Jev Engineering for Coding Agents* (§I–XII). One page of judgment, not definitions (use `glossary.md` for terms).

## Decision rules

| When | Do | Because |
|---|---|---|
| Context on every turn | Ask Jev; score each chunk hide/short/long/full | Context is assembled, not accumulated (§V) |
| A cheap model might do the subtask | Route **only** if it gets a small purpose-built context and the return trip avoids a reread | Routing priced per token is the trap (§II.A) |
| Session is long (large X) or read-heavy (Z ≫ Y) | Stay on the frontier | 3X+20Y+8Z vs 25Y+5Z; 6.19 vs 4.15 (§II.A) |
| You feel like compacting | Don't compress before the question is known | A pre-question summary discards what is needed (§II.C) |
| You want a tool available | Ship a Tier-1 snippet; pay for Tier-2 schema only when chosen | Up-front schemas cost context forever (§II.B, §VII) |
| You need long-lived guidance | Attach it to a **condition**, not the session | Conditional fragments are compaction-immune (§VIII) |
| Transcript has drifted | Reload only still-relevant chunks, don't reload the transcript | Restarts discard good state with bad (§II.E) |
| Spawning a subtask | Register + dedupe against prior subgoals first | Avoid duplicate/in-flight work (§VI.B) |
| Many background tasks | Share one retrieval pass; keep them read-only | Retrieval dominates; read-only never contends (§X) |
| Choosing where data may go | Classify sensitivity first, then route | Trust is a third routing axis (§IX) |
| Adding a built-in | Ask "does it cost nothing until used?" | Every battery costs context permanently (§II.F) |
| Optimizing the agent | Optimize retrieval before the model or diff format | Reading+searching ≈ two thirds of tokens (§III) |

## Thresholds & defaults

- **Token shares** (input-heavy): read files 30–40%, search 10–18%, command output 10–20%, sys/tools/AGENTS.md 5–12%, reasoning 5–15%, edit 4–10%, explain 2–5%.
- **Retrieval dominance**: fastcontext (GPT-5.4 trajectories) — reading+searching = 56.2% of tool-use turns, 46.5% of main-agent tokens.
- **Routing arithmetic**: Path 1 `25Y+5Z`; Path 2 `3X+20Y+8Z`; example X=.65 Y=.12 Z=.23 → 4.15 vs 6.19.
- **Prices used in the paper** (may have changed): Opus $5 in/$25 out; Sonnet $3 in/$15 out per M tokens.
- **Visibility ladder default**: if unsure between summaries, pick the shorter one; the chunk is never deleted from state.
- **Sensitivity bands** (Table IV): open → any cheapest · standard → vetted providers · restricted → first-party frontier only · custom → excludes named vendors.
- **Eval-before-switch**: mirror live traffic to a candidate model for ~a day before switching (§X).

## Tells & smells

- **Routing added cost** → you priced per token, not per context rebuild.
- **The tool list crowds the window** → schemas are declared up front instead of tiered.
- **Compaction lost a fact the next query needed** → compression happened before the question.
- **Almost no sub-agent calls** → context passing is expensive/error-prone, so the model avoids it.
- **A restart was needed after drift** → state is a transcript, not addressable chunks.
- **Debating batteries-included** → you are still paying permanent context for unused built-ins.
- **A grep result is shown in full every turn** → no per-query visibility scoring.

## One-line thesis

Make state explicit and typed; let Jev decide context, routing, tools, and permissions **per query** — none of it requires a better model.

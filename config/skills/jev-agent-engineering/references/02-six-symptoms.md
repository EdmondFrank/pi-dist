# §II — Six Symptoms of the KV Cache

Source: §II (intro) and §II.A–§II.F of *Jev Engineering for Coding Agents*. Table II lists six design choices current agents inherit.

## Core idea

Each symptom is not a bug in a model — it is a **consequence of append-only context under KV-cache economics**. All six have the same one-move cure: make state explicit and typed (§II intro, §XII).

## Table II — Six design choices current agents inherit

| # | Symptom | Why it exists | What it costs |
|---|---|---|---|
| 1 | Routing fails | Handing back to the large model reprocesses context | Mixed routes cost more than pure frontier |
| 2 | Tools crowd context | Schemas must sit in the system message | Tokens spent on irrelevant tools; weaker selection |
| 3 | Compaction | One shared state assumed for all future turns | Query-blind compression loses what matters later |
| 4 | Sub-agents are rare | Choosing what context to pass in and merge back is hard | Little automatic parallelism |
| 5 | Restarts | Stateful transcripts corrupt over time | Relevant old state discarded with the bad |
| 6 | Batteries debate | Every built-in costs permanently | Forced choice between ease and power |

## §II.A — Routing does not work

The intuitive plan: let a frontier model **plan**, hand **execution** to a cheaper model, bring the frontier model back to **review**. The notes run the numbers with Opus at $5 in / $25 out and Sonnet at $3 in / $15 out per million tokens. Let **X = context tokens, Y = generated output tokens, Z = additional tokens read** during the work (command output, file reads).

```
Path 1  pure Opus          generate 25·Y ; read 5·Z                    total 25Y + 5Z
Path 2  Opus → Sonnet → Opus
        Sonnet loads context   3·X
        Sonnet generates      15·Y
        Sonnet reads           3·Z
        Opus reloads what changed  5·(Y+Z)
                                                       total 3X + 20Y + 8Z
```

- Path 2 is **more expensive** whenever the session is long (large X), whenever the work reads substantially more than it writes, or a combination.
- Plausible session shape X=0.65, Y=0.12, Z=0.23 → **4.15 for pure Opus vs 6.19 for the routed path**. Staying on the frontier costs roughly **two-thirds** as much as the route meant to save money.
- **The lesson is not that routing is wrong** — it is that *routing priced per token rather than per context rebuild is wrong*. Routing becomes viable only when the harness can hand the cheaper model a **small, purpose-built context** instead of the full transcript, and when the return trip does **not** force the frontier model to reread everything the helper produced.

## §II.B — Tool calling is a weird tradeoff

- Tools must be declared **up front in the system message with full argument schemas**, relevant or not. This consumes a large share of context and does **not** produce especially smart tool selection.
- Working hypothesis: models struggle with some combination of **high cardinality** (many tools at once) and **off-policy tool calling** (tools whose usage patterns differ from training).
- May be part of why **skills** — which load a short description and defer detail — often outperform raw tool lists and MCP servers.

## §II.C — Compaction exists

- Compaction makes perfect sense **if every future turn wants the same shared state**. The notes question that assumption.
- Compaction attempts **generic** compression: hard and lossy.
- **Query-aware** compression is far easier: if you know what the next question is, you know what to keep. A summary written **before** the question is known will reliably throw away something the question needed.

## §II.D — Sub-agents are meh

- Models parallelize **less than one would expect**. Suspected cause: **state management** — deciding which parts of the parent context to pass in, and which parts of each sub-agent's findings to merge back.
- When that decision is **expensive and error-prone, the model avoids it**.

## §II.E — Restarting exists

- Restarting is the standard remedy for a transcript that has drifted or become corrupted — it discards the **bad state and the good state together**.
- With **addressable state**, the alternative is to start clean and **reload only the old chunks that are still relevant, on demand**.

## §II.F — Batteries are not included

- Standing debate: should agents ship built-in capabilities? Today it is a tradeoff between **ease of use** (heavily-batteried agents) and **power** (tools like Claude Code and Codex).
- The tradeoff exists **because every battery costs context permanently**. *Remove that cost and the debate dissolves.*

## Connects to

- §III (the cost numbers behind routing), §IV–§VII (the proposed fixes), §XI (batteries shortlist).

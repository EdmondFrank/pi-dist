# §III — Where Tokens Actually Go (and the Routing Arithmetic)

Source: §II.A (arithmetic) and §III of *Jev Engineering for Coding Agents*, plus Table III and Figs. 2–3.

## Core idea

Before redesigning a harness, know which part of a session consumes the budget. In a typical CLI coding-agent session, **reading and searching dominate; writing code is among the smallest line items**. The largest efficiency gain in a coding agent is therefore **not a better model or a better diff format — it is smarter retrieval**.

## Table III — Token share by subtask (input-heavy view)

Repeated rereads count each time, so this is an input-heavy view.

| Subtask | ~Share | Note |
|---|---|---|
| Reading file contents | 30–40% | Largest bucket; files re-read as context |
| Searching the codebase | 10–18% | grep, glob, listings; noisy output |
| Command output | 10–20% | Stack traces and logs balloon on failure |
| System prompt, tool schemas, AGENTS.md | 5–12% | Fixed overhead paid on every turn |
| Conversation replay | *amplifier* | Why everything above is counted repeatedly |
| Reasoning and planning | 5–15% | Higher on hard debugging |
| Writing and editing code | 4–10% | Diffs and str_replace edits are compact |
| Explaining to the user | 2–5% | Terse by design in CLI agents |

Midpoint estimates used in Fig. 3: read files 35%, search 14%, commands 15%, sys 8%, reasoning 10%, edit 7%, explain 3%.

**Retrieval (reading + searching + command output) ≈ two thirds of processed tokens; writing code is under a tenth.**

## Independent corroboration

Microsoft's **fastcontext** project reports that in GPT-5.4 trajectories, reading and searching account for **56.2% of all tool-use turns** and **46.5% of the main agent's total tokens**. If that generalizes, the biggest available saving is retrieval.

## The routing arithmetic (Figs. 2, and §II.A)

Prices used: Opus $5 in / $25 out, Sonnet $3 in / $15 out per M tokens. X = context tokens, Y = generated output, Z = additional tokens read.

| Path | Composition | Total |
|---|---|---|
| 1 — pure Opus | generate 25·Y + read 5·Z | **25Y + 5Z** |
| 2 — Opus → Sonnet → Opus | Sonnet load 3X + Sonnet gen 15Y + Sonnet read 3Z + Opus reload 5(Y+Z) | **3X + 20Y + 8Z** |

Worked example, X=0.65, Y=0.12, Z=0.23:

| Component | Relative cost |
|---|---|
| Sonnet loads context | 1.95 |
| Sonnet generates | 1.80 |
| Sonnet reads | 0.69 |
| Opus reloads what changed | 1.75 |
| **Routed total** | **6.19** |
| **Pure Opus total** | **4.15** |

Crossover intuition: routing wins only when **X and Z are small relative to Y** — i.e. short sessions, write-heavy work, and a return trip that does not reread. The harness must supply a **small, purpose-built context** to the cheap model for routing to pay off.

## Connects to

- §II.A–§II.F (symptoms), §VI (routing revisited once contexts are dynamic), §X (sharing retrieval across background tasks is "the largest single saving available").

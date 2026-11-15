# §VIII — Conditional Instructions

Source: §VIII of *Jev Engineering for Coding Agents*, Fig. 6. Plus §VIII.A (structured skills) and §VIII.B (recursive language models).

## Core idea

`AGENTS.md` files **load in full today**. The notes propose loading sections **conditionally** — instructions **attach to conditions rather than to the session**, and a conditional fragment is **pinned so compaction cannot summarize it away**.

## Fig. 6 — Conditional AGENTS.md

| Condition (current task) | Fragment loaded |
|---|---|
| touches `*.tsx`? | `style-guide.md` |
| inside `billing/`? | `billing/GOTCHAS.md` |
| writing prose? | voice samples + don'ts |

- Working on front-end code loads the style guide.
- Working inside a particular subdirectory loads **that directory's footguns file** — the notes suggest **every subdirectory should have one**.
- In ordinary chat the same need appears: a request for a **summary** should pull in a **preferred format**; a request for **writing in one's own style** should pull in **samples and a list of things to avoid**; a request for **code** should pull in a **style guide and a note not to add a million assertions**.

## Skills vs conditional instructions

| | Skills | Conditional instructions |
|---|---|---|
| Meaning | "do this now" | "keep this in memory somewhere" |
| Lifetime | loaded once, can be compacted/summarized out | reloaded **whenever the condition holds** |
| Key property | — | **immunity to compaction** |

A skill loaded early in a long session will eventually be compacted out. A condition-bound instruction does not, because it is **re-pinned whenever its condition holds**.

## §VIII.A — Structured skills

- Depending on how programmable the harness becomes, **skills could carry behavioral changes, not just instructions** — similar to Claude Code's skill hooks but more powerful.
- Limitation flagged in current hook systems: **once added, a hook stays in the session permanently**.
- **Structured skills** would **attach and detach behavior with the condition that triggered them**.

## §VIII.B — Recursive language models

- A related direction treats **more of the agent's state as explicit variables rather than transcript text**.
- A world where state is held in **named variables** could be considerably cleaner than one where state is **whatever happens to remain in the context window**. (Attributed to A. Zhang, 2025.)

## Connects to

- §II.C (compaction), §V (visibility ladder), §VII (skills defer detail), §X (background tasks extend the same read-only pattern).

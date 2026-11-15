# §V–§VI — Meta-Attention: Context as a Decision

Source: §V and §VI of *Jev Engineering for Coding Agents*, Figs. 4–5. This is the paper's central proposal.

## §V — The central proposal

**Context is not static.** For every user query the harness asks Jev **two things**:

1. **How good is the previous context?** Should the existing **KV cache be reused**, or is **rebuilding from scratch** cheaper and better? Framed as an explicit, **cost-aware decision** rather than a default.
2. **How to construct a new context** that contains everything relevant and nothing else.

- In its simplest form this is a **noul on every chunk of context**: each tool call input, each tool call output, each piece of internal reasoning, and possibly each exchange with the user.
- A later version **replaces the score with a visibility level**.

## The visibility ladder (Fig. 4)

The same chunk can be hidden, summarized briefly, summarized at length, or shown in full, depending on the current query:

| Example chunk | Visibility |
|---|---|
| grep output, 2,400 lines | **SHORT SUMMARY** · 12 hits |
| test log, failing run | **LONG SUMMARY** · trace + cause |
| file: auth/session.ts | **FULL** · relevant to query |
| old plan, superseded | **DON'T SHOW** |

Ordering: **hide / short / long / full**.

- **Payoff**: the idea behind compaction survives while its main flaw disappears. Compaction compresses **once, before knowing the question**. The ladder compresses **per query, after knowing it**. A 2,400-line grep result can be **twelve relevant hits for one question and invisible for the next**, without ever being deleted from state.
- **Heatmap idea**: if the harness can heatmap which part of a grep output is relevant, it can filter that output down by any amount the budget allows.

## §VI — Routing and sub-agents revisited

- **First-class dynamic contexts are what make routing work again.** Handing a subtask to a cheaper or faster model no longer requires the cheap model to load the whole session, and the result can be merged back as a **scored chunk** rather than a transcript the frontier model must reread. Everything stays cost-aware and intelligence-aware.
- The same mechanism **unblocks sub-agents**: the notes' guess is that a large share of sub-agent cost today is the work of deciding what context to pass, versus a simple instruction of the kind a user would type. If building that context becomes **cheap and automatic**, sub-agents can be used far more often.
- It also opens a **user-facing control**: spend more for faster or better results, or run conservatively and spend as little as possible.

### §VI.A — Extreme parallelism

- If spawning tasks becomes cheap, many run at once and the harness inherits the problems of concurrent systems: **synchronization primitives, inter-agent communication, and write collisions when several agents share state**.
- Suggested design: **shared state with locks**. Explicit **typing of reads versus writes** is what makes this tractable, because **read-only tasks never contend**.

### §VI.B — Deduplicating goals

- For goal-driven loops such as `/goal`, an open question is whether the agent **repeats work**.
- Mitigation: before spawning any subtask, **register it as a subgoal and deduplicate it against all previous subgoals**. Work already done, or already in flight, is **never launched twice**.

## Connects to

- §II.C (compaction's flaw), §III (retrieval cost), §VII (tiered disclosure is the tool-side of the same idea), §X (shared retrieval for background tasks).

---
name: jev-agent-engineering
description: Design coding-agent harnesses with typed decisions.
---

# Jev Engineering for Coding Agents

A knowledge base distilled from the 2026 working note *Jev Engineering for Coding Agents* — an independent study synthesis of design notes by Diogo Almeida, founder of TypeSafe. It explains how to design a coding-agent harness around **explicit, typed state**, and let a decision layer (Jev) answer the per-turn questions: which context to show, whether to reuse the cache, which model and tool to use, whether a command may run. It is design guidance, not a runnable harness — there is no Jev runtime here, and the paper's numbers are illustrative list-price estimates, not current billing. The concrete bridge is the existing `smart---smart_decide` tool, whose typed answers (`noul`, `choice`, `score`) match Jev's one-to-one.

## When to Use

- "My agent's context keeps bloating / compaction loses what matters later"
- "Should I route this subtask to a cheaper model?"
- "Why do sub-agents rarely fire?" / "How do I make tool calling cheaper?"
- Designing permission policy or approval rules for an agent harness
- Deciding what belongs in `AGENTS.md` vs a skill vs a conditional fragment
- Applying Jev / TypeSafe decision-model ideas to an agent you are building
- "How do I use `smart---smart_decide` for routing, tool pick, or permission checks?"

## Prerequisites

- No runtime, no API keys. This skill is documentation plus a bridge to one existing tool.
- Source: 12-page PDF, sections I–XII, 5 tables, 7 figures. To re-extract it, invoke `power---bash` with `pdftotext -layout <pdf> /tmp/jev.txt`.
- `smart---smart_decide` (System One model, default `Bespoke-Nimble-9B`) must be available for the typed-decision bridge.

## How to Run

Apply it as a review checklist over a harness decision you are making right now. Load only the reference file you need (`references/` files cost nothing until read), then convert the decision into a typed `smart---smart_decide` call — see `references/smart-decide-mapping.md`. Frame measurement with AiderDesk tools: `power---grep` / `power---semantic_search` for retrieval, `power---file_read` for contents, `power---glob` for discovery, `programmatic_tool_calls` when one turn needs several calls at once.

## Quick Reference

| Jev decision point | Question to Jev | Typed answer | `smart_decide` type |
|---|---|---|---|
| Context | How visible should this chunk be for this query? | hide / short / long / full | `choice` |
| Cache | Reuse the cached prefix or rebuild? | noul + probability | `noul` |
| Routing | Can this subtask leave the frontier model? | choice + cost estimate | `choice` |
| Tools | Which tool fits this intent? | ranked choice, top-k | `choice` |
| Permissions | Should this command run? | allow / ask / deny | `choice` |
| Security | Which files will this task touch? | sensitivity score | `score` |

**Six symptoms of the KV cache** (Table II): routing fails, tools crowd the window, compaction is blind, sub-agents are rare, restarts discard good state, the batteries debate exists. **One move fixes all six**: make state explicit and typed, and let Jev decide context, routing, tools, and permissions per query.

## Procedure

1. **Measure retrieval first.** Retrieval dominates a session: reading files 30–40%, searching the codebase 10–18%, command output 10–20% of processed tokens, against writing/editing code at only 4–10%. Use `power---grep`, `power---glob`, `power---semantic_search` deliberately, and pull snippets with `power---file_read` rather than dumping whole files.
2. **Make state addressable.** Hold context as named, typed chunks instead of an append-only transcript, so a chunk can be hidden or shortened without being deleted from state.
3. **Ask the six questions every turn** (Quick Reference), answering each with a typed `smart---smart_decide` call rather than prose.
4. **Score chunks on the visibility ladder** before assembling context: hide / short summary / long summary / full (Fig. 4). This is query-aware compression and it replaces blind compaction.
5. **Price routing per context rebuild, not per token.** Hand a cheaper model a small purpose-built context, and make the return trip avoid a full reread.
6. **Disclose tools in tiers**: Tier 1 snippets for hundreds of capabilities, Tier 2 full schema on demand for the chosen few, Tier 3 docs for a one-off query.
7. **Attach instructions to conditions**, not to the session (conditional `AGENTS.md`), so they reload whenever the condition holds instead of being compacted away.
8. **Route by sensitivity**, not only by difficulty and cost (see `references/08-security-routing.md`).
9. **Share one retrieval pass** across read-only background tasks; type reads vs writes so read-only work never contends for locks.

## Pitfalls

- **The routing trap.** Routing priced per token looks cheaper and often is not. Path 2 (frontier → cheap → frontier) costs `3X + 20Y + 8Z` against Path 1 (frontier only) at `25Y + 5Z`, where X = context tokens, Y = generated output, Z = extra tokens read. At X=0.65, Y=0.12, Z=0.23 the routed path is **6.19** vs **4.15** — staying on the frontier is about two-thirds the cost. Recompute with your own X/Y/Z.
- **Compaction before the question is known** reliably discards what the next query needs. Compress per query, not once.
- **Tool schemas declared up front** consume context permanently without improving selection; skills (short description, deferred detail) often beat raw tool lists and MCP servers.
- **Every battery costs context forever** — that is the entire ease-vs-power debate.
- **Restarting discards good state with bad.** With addressable state, reload only the still-relevant chunks.
- **Numbers are illustrative.** The token-share table is an estimate of CLI coding-agent sessions; the 56.2% tool-use-turns / 46.5% main-agent-tokens figures are Microsoft fastcontext's, reported on GPT-5.4 trajectories. List prices may have changed.
- The paper is an independent synthesis, not affiliated with or endorsed by TypeSafe, Anthropic, OpenAI, Microsoft, or any project named.

## Verification

Run one `smart---smart_decide` noul call on a real harness question (e.g. "reuse the cached prefix this turn?") and confirm it returns a probability instead of prose — that proves the Jev↔`smart_decide` bridge is live. Then `power---glob` `references/*.md` and confirm every file named in the index exists.

## Reference Index (load on demand)

| File | Load this when |
|---|---|
| `references/01-thesis-explicit-state.md` | You need the core argument, "why yet another agent", and the Jev question set |
| `references/02-six-symptoms.md` | Diagnosing an agent harness that feels wrong |
| `references/03-token-economics.md` | Costing a session or checking the routing arithmetic (Tables I–III) |
| `references/04-permissions-tool-routing.md` | Writing permission policy or routing intent to a tool |
| `references/05-context-as-decision.md` | Context assembly, the visibility ladder, sub-agents, parallelism |
| `references/06-tools-tiers-and-batteries.md` | Tool disclosure tiers and the built-in shortlist (Fig. 5, Table V) |
| `references/07-conditional-instructions.md` | `AGENTS.md` design, structured skills, recursive language models |
| `references/08-security-routing.md` | Routing by data sensitivity and trust (Table IV) |
| `references/09-background-processing.md` | Background reviewers, evals, and the shared retrieval pass (Fig. 7) |
| `references/smart-decide-mapping.md` | Turning any Jev question into a concrete `smart---smart_decide` call |
| `references/cheatsheet.md` | Decision rules, thresholds, and tells on one page |
| `references/glossary.md` | Term definitions with section references |

# §I — Why Yet Another Agent: the Explicit-State Thesis

Source: §I and §I.A/§I.B of *Jev Engineering for Coding Agents* (2026 working note).

## Core idea

A coding agent is a **loop around a model with a handful of tools**, and the loop is *not* where the leverage is. The leverage is in **what the loop feeds the model each time it turns**. The notes' thesis: some capabilities can only be built natively because they require control over how context is assembled on every turn — so build a harness that treats context as **assembled on purpose, not accumulated by accident**.

## The four working assumptions

1. **Coding agents are simple** — especially the agentic part: a loop, a model, a handful of tools. There has been little meaningful innovation outside the model itself.
2. **The best parts of existing agents can be reused** — frontier models are all reachable through APIs; open-source projects provide inspiration and even UI components; only a few areas (e.g. authentication for MCP servers) carry real complexity.
3. **The first-party cost advantage may be shrinking** — usage is drifting toward pay-as-you-go API pricing rather than bundled subscriptions.
4. **Some capabilities can only be built natively** — they cannot be delivered as a plugin to someone else's agent, because they require control over how context is assembled on every turn. *This assumption is the thesis.*

## Where Jev sits

- Jev is **not the model that writes the code**. It is the **decision layer beside it** (Fig. 1: "Jev Decisions" beside "Explicit State").
- The harness hands Jev the **current application state** — goal, context, rules, available actions, previous actions — together with a **predefined question**.
- Jev returns a **typed answer**: a choice, a score, or a noul decision, each with a probability.
- Frontier models, sub-agents, tools, and deterministic code then do the actual work.
- Because the output is **typed rather than free-form**, the harness can validate it, apply thresholds, and branch on it **without parsing prose**.

## Every native feature is a Jev question

Any native feature is, underneath, a high-frequency decision point. Asked **thousands of times per session**, those small decisions are where the notes locate the leverage.

| Decision point | Question to Jev | Typed answer |
|---|---|---|
| Context | How visible should this chunk be for this query? | choice: hide / short / long / full |
| Cache | Reuse the cached prefix or rebuild? | noul + probability |
| Routing | Can this subtask leave the frontier model? | choice + cost estimate |
| Tools | Which tool fits this intent? | ranked choice, top-k |
| Permissions | Should this command run? | allow / ask / deny |
| Security | Which files will this task touch? | sensitivity score |

*(Table I, verbatim structure.)*

## The organising question

> "How would you design a coding agent if LLMs had no KV cache?"

- The **KV cache** is why agents are built as **append-only transcripts**: reusing a cached prefix is cheap, but changing anything early in the context invalidates the cache and forces the model to reprocess everything after the change. A single economic fact that shapes almost every current design decision — usually without anyone stating it.
- Imagining the cache away does two things:
  1. It permits a **state-explicit design built for Jev**, where context is **assembled rather than accumulated**.
  2. It reveals why ideas that feel intuitively correct — like routing easy work to a cheap model — **fail in practice**. The notes call this the *tyranny of the KV cache* (§II).

## Vocabulary introduced here

- **Jev** — TypeSafe's decision model, described from TypeSafe materials as returning typed choices, scores, and noul decisions with probabilities.
- **noul** — a binary (yes/no) decision returned with a probability.
- **Harness** — the system around the model; Fig. 1 splits it into Explicit State (left) and Jev Decisions (right), feeding Context Assembly and a Router into the Runtime.

## Connects to

- §II (six symptoms the cache produces), §V (context as a decision), §III (where tokens actually go).

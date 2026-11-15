# §X — Background Processing

Source: §X of *Jev Engineering for Coding Agents*, Fig. 7.

## Core idea

Across several popular agent workflows, an **emerging pattern**: work that runs **in the background**, as an extension of the normal coding workflow, and is a **read-only function of the current codebase state**. Because it is read-only, it never contends for locks — and because retrieval is shared, the expensive part is paid once.

## The workflows observed

- Building **HTML pages that update in parallel** as work proceeds.
- The argument that **understanding, not generation, is the new bottleneck**.
- **Generating evals in the background.**
- An **ELI5 skill** that explains a system with a few big pictures and very few words.
- An agent maintaining a small **deployed progress page** (screenshots + notes) that can be checked from a phone during a long run.
- A production pattern that **mirrors live traffic to a candidate model** and generates evals automatically for **roughly a day** before any switch is made.

## Fig. 7 — Background processing on explicit state

```
MAIN AGENT writes
      │
      ▼
SHARED RETRIEVAL  — relevant files, symbols, diffs, found once
      │
      ├── cross-model review
      ├── background eval generation
      ├── ELI5 explainer · quizzes
      ├── live progress page
      └── micro-world simulations
                     read-only · never contend for locks
```

- **Cross-model review** — having one vendor's agent review another's work — fits the same mold.

## Why this is where the Jev thesis pays off

- A Jev-centric harness has to be **precise about what is in context** and **whether each operation reads or writes**.
- **Finding the information relevant to a code change is non-trivial work.** If that retrieval is **shared across all background tasks** rather than repeated by each one, running them becomes much cheaper — and it becomes **economical to run many more of them**.
- Given §III's finding that **retrieval dominates the token budget**, sharing it is **the largest single saving available**.
- In the notes' words, being explicit about reads versus writes *should eventually give the agent superpowers.*

## Connects to

- §III (retrieval dominates), §V (context as a decision), §VI (sub-agents and shared state), §IX (reviewers must respect data sensitivity).

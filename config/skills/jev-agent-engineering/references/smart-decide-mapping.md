# The Bridge: Jev Questions as `smart---smart_decide` Calls

Source: the paper's typed-decision model (§I.A, Table I) combined with the AiderDesk `smart---smart_decide` tool (System One, default model `Bespoke-Nimble-9B`). This file is the practical "combine" of the two.

## Why they are the same shape

- **Jev** hands the harness a typed answer: a **choice**, a **score**, or a **noul decision**, each **with a probability**; frontier models, sub-agents, tools, and deterministic code do the work, and the harness validates/branches **without parsing prose** (§I.A).
- **`smart---smart_decide`** scores the allowed answer tokens directly and returns the chosen answer **with a calibrated probability**; it generates no free-form text. Question types: `noul`, `choice`, `score`.

The paper's "harness asks Jev thousands of times per session" is implementable today: batch the turn's decision points into **one** `smart---smart_decide` call and branch on the returned probabilities.

## Tool contract (from the tool definition)

- `state` — the application state to evaluate: goal, current query, assembled context/rules, available actions, previous actions (mirrors the paper's "goal, context, rules, available actions, previous actions").
- `questions` — map of `id` → `{ type, instructions, criteria }`:
  - `noul` — yes/no judgment; returns **P(yes)** in 0–1.
  - `choice` — pick one option; `criteria` maps each option to its rubric, or is a list of option strings.
  - `score` — rate on an ordered rubric; `criteria` is an ordered list of levels (≥2); returns probability-weighted score.
- `compact: true` — drop probability detail (use `false` when the harness needs thresholds).
- Every question **requires non-empty `instructions`**; bad arguments come back as field-level validation errors — fix and retry rather than switching tools.

## Decision-point mapping

| Jev decision point | Question to Jev | `smart_decide` type | `criteria` shape |
|---|---|---|---|
| Context | chunk visibility for this query? | `choice` | hide / short / long / full |
| Cache | reuse cached prefix or rebuild? | `noul` | — (returns P(reuse)) |
| Routing | can this subtask leave the frontier? | `choice` | frontier / cheap / sub-agent |
| Tools | which tool fits this intent? | `choice` | one rubric per candidate tool |
| Permissions | should this command run? | `choice` | allow / ask / deny |
| Security | which files will this task touch? | `score` | open → restricted, ordered |

## One turn, six questions, one call

Invoke via the `smart---smart_decide` tool — or from `programmatic_tool_calls` when the turn also needs retrieval calls (`power---grep`, `power---file_read`) in the same pass.

```json
{
  "state": {
    "goal": "fix the failing auth test",
    "query": "why does session.test.ts fail?",
    "chunks": [
      {"id": "grep-2400", "desc": "2400-line grep of 'session'"},
      {"id": "trace", "desc": "full failing stack trace"},
      {"id": "session.ts", "desc": "diff of auth/session.ts"}
    ],
    "command": "npm test -- --runInBand",
    "touched_files": ["src/auth/session.ts", "src/auth/session.test.ts"]
  },
  "questions": {
    "cache_reuse": {
      "type": "noul",
      "instructions": "Reuse the existing KV cache prefix for this turn? Yes = reuse, no = rebuild context from scratch. Weigh the cost of invalidation against how much of the previous context still fits."
    },
    "chunk_grep": {
      "type": "choice",
      "instructions": "How visible should this 2400-line grep chunk be for this query?",
      "criteria": {
        "hide": "irrelevant to this query",
        "short": "a hit count is enough",
        "long": "needs context around the hits",
        "full": "must be quoted verbatim"
      }
    },
    "route": {
      "type": "choice",
      "instructions": "Where should this subtask run? Price routing per context rebuild, not per token.",
      "criteria": {
        "frontier": "needs the frontier model end-to-end",
        "cheap": "small purpose-built context; return trip avoids a full reread",
        "subagent": "parallelizable and state passing is cheap"
      }
    },
    "tool": {
      "type": "choice",
      "instructions": "Which tool fits this intent?",
      "criteria": ["power---grep", "power---semantic_search", "power---file_read", "power---glob"]
    },
    "permit": {
      "type": "choice",
      "instructions": "Should this command run?",
      "criteria": {
        "allow": "read-only, or expected tests with an anticipated exit code",
        "ask": "writes outside the repo root",
        "deny": "touches ~/.ssh or .env*, or has unexplained network egress outside deploy"
      }
    },
    "sensitivity": {
      "type": "score",
      "instructions": "How sensitive is the data this task will touch?",
      "criteria": ["public docs / OSS deps", "application code", "secrets, env, infra config", "proprietary research code"]
    }
  },
  "compact": false
}
```

## How the harness uses the result

- **Threshold on probability**, do not re-ask in prose: e.g. route away from the frontier only if `route = "cheap"` with high confidence; else stay on the frontier (§II.A: staying is often two-thirds the cost).
- **Chain typed decisions**: `sensitivity` (`score`) feeds `route` (`choice`) — the eligibility band comes from Table IV, not from the model's mood.
- **Store the answer as a scored chunk**, not a paragraph, so the frontier model can branch on it without rereading a transcript (§VI).
- **Deduplicate subgoals** (§VI.B) by keeping prior `route`/`tool` answers as named state variables rather than transcript text (§VIII.B, recursive language models).

## Anti-patterns

- Asking `smart_decide` to **generate** text — it scores allowed answer tokens and returns no reasoning. Use it for routing, policy checks, and rubric scoring only.
- Passing an **open-ended instruction** with no closed `criteria` — give it a finite option set (choice) or an ordered rubric (score).
- **One question per call** in a hot loop: batch all six decision points into a single call with one `state`.
- Using the probability as decoration: if you never branch on it, you have re-implemented prose parsing with extra steps.

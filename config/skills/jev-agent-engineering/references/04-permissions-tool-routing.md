# §IV — Basic Layer: Permissions and Tool Routing

Source: §IV of *Jev Engineering for Coding Agents*. Two improvements that could be integrated into **any** existing agent, native or not.

## §IV.A — Programmable permissions

- Every command an agent runs raises one question: **should it run at all?**
- Claude's auto mode answers with a **classifier**. The notes propose going further: permissions expressed as **programmable queries over what is and is not allowed**, plus **deeper inspection where the stakes justify it** — for instance reading the contents of a Python or shell file before executing it, rather than approving the command name alone.
- Illustrative policy (as printed in the paper — a design sketch, not a real product syntax):

```
policy "exec":
  deny   if command touches ~/.ssh or .env*
  deny   if script contents contain network egress and task.scope != "deploy"
  ask    if command writes outside repo root
  allow if command in read_only_set
  allow if tests/ and exit code is expected
```

- Shape of the rule set: **deny** on secret/infra paths and on unexplained network egress; **ask** on writes outside the repo root; **allow** for a known read-only set or expected test runs.
- This maps directly to a typed `allow / ask / deny` **choice** — see `smart-decide-mapping.md`.

## §IV.B — The harness as tool router

- Instead of exposing **every** tool schema to the model, the harness **sits between intent and invocation**.
- The model **describes what it is trying to do in plain text**. The harness then uses a **sequence of typed Jev calls** to select the single best tool, or the top few candidates, and **constructs the arguments**.
- Two payoffs:
  1. The model never has to hold hundreds of schemas in context.
  2. A wrong argument type becomes a **validation error** rather than a **silent failure**.

## Connects to

- §V (context as a decision), §VII (tiered tool disclosure), §IX (routing by sensitivity). The tool-router idea is what makes the six decision points of Table I answerable per turn.

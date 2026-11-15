# §VII & §XI — Tools, Tiers, and the Batteries Shortlist

Source: §VII and §XI of *Jev Engineering for Coding Agents*, Fig. 5 and Table V.

## §VII — Tools and skills from first principles

- The notes argue for a **layer between today's always-loaded tools and on-demand skills**.
- A model **cannot propose an action it does not know exists**, so it needs **short snippets** describing what is available — similar to skill descriptions. But those snippets **need not live in the system message**: they can **load dynamically when relevant**.
- Behind the snippets sits the ability to **dump the full schema** of available actions when needed, similar to a tool-search tool.
- The requirement that ties it together: **none of this corrupts the context once it is no longer needed.**

## Tiered disclosure (Fig. 5)

| Tier | What the model sees | Cost profile |
|---|---|---|
| Tier 1 — snippets | one line per capability, loaded when relevant; **100s of tools** | cheap map of everything |
| Tier 2 — schema on demand | full arguments for the chosen few | paid only on selection |
| Tier 3 — docs | manual for a one-off query | dropped from context when done |

Cost per turn rises down the tiers; **detail drops from context when done**.

- If this works, **the batteries debate from §II disappears**: a built-in costs almost nothing until it is used, so an agent can ship with **hundreds of tools and thousands of documentation pages**.
- Second benefit: **near-zero-cost integrations are a strong co-marketing channel**, and they let things simply work.

### §VII.A — Better batteries

- Many community tools promise to help agents and in practice do not. The notes cite a **tool-output compressor** as an example and guess the cause: **models do not natively understand these tools**.
- A native harness can ship **first-party prompts that teach the model how to use each one** — effectively a **built-in sub-agent or skill per tool** — and its clean context means the tool's custom logic **does not poison the rest of the session**.
- Marketing angle: shipping integrations for whatever tools are currently popular keeps the agent in the conversation.

## §XI — Batteries shortlist (Table V)

| Project | Role | Native angle |
|---|---|---|
| headroom | context compressor | classifier checks the compression kept the needed facts |
| **rtk** | tool-output compressor | first-party prompts so the model understands it |
| ast-grep | structural search | load manual once, generate N queries, filter by relevance |
| ast-outline | structural outline | hierarchical calling: pick the sub-tree to inspect |
| fastcontext | repo-exploration sub-agent | route to it, or replace its search with structure |
| fff | path and content search | in-memory index, frequency-ranked, faster than ripgrep in long sessions |

Skill-level note: `rtk` is already the convention in this environment (shell commands are wrapped with it), so the "first-party prompts so the model understands it" angle applies as-is; `headroom`'s "classifier checks the compression kept the needed facts" is exactly what a `smart---smart_decide` score/noul can supply.

## Connects to

- §II.B (tools crowd context), §IV.B (harness as tool router), §VIII (structured skills).

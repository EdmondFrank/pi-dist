# §IX — Security-Aware Routing

Source: §IX of *Jev Engineering for Coding Agents*, Table IV.

## Core idea

Routing today is framed around **difficulty** and **cost**. The notes add a **third axis: trust.**

- Open-weight models served through low-cost providers are **dramatically cheaper** than frontier APIs, but data passing through **some of those endpoints may not stay private**.
- The proposal: give each subtask an **estimate of which kinds of files it is likely to touch**, **attach policies to file types**, and **route subtasks accordingly**.
- This is the **sensitivity score** decision point from Table I, and it is what makes security a routing input rather than a discipline.

## Table IV — Routing by data sensitivity

| Files likely touched | Policy | Eligible models |
|---|---|---|
| Public docs, open-source deps | open | any, cheapest first |
| Application code | standard | vetted providers |
| Secrets, env, infra config | restricted | first-party frontier only |
| Proprietary research code | custom | excludes named vendors |

## Beyond difficulty and cost

- Difficulty and cost are **not the only reasons to route**. A team might **avoid one vendor's models for its own model research**, or **avoid certain providers for safety-sensitive work**.
- Once routing is **policy-driven**, those preferences become **configuration rather than discipline** — they stop depending on a human remembering them per task.

## Two-layer pattern

1. **Classify** the data the task will touch → a sensitivity **score**.
2. **Select** eligible models from the policy for that band → a routing **choice**.

Both are typed `smart---smart_decide` calls (`score` then `choice`) — see `smart-decide-mapping.md`.

## Connects to

- §IV.A (permissions), §VI (routing revisited), §X (background reviewers also touch data).

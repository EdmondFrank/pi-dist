---
name: yagni-principle
description: >
  Apply YAGNI (You Aren't Gonna Need It) when tempted to build features,
  parameters, endpoints, or abstractions for hypothetical future requirements.
  Use during implementation and code review to cut speculative scope, defend
  the minimal viable implementation, and keep the codebase lean.
---

# YAGNI — Don't Build Unnecessary Features

## Core idea

Build only what is needed today, not what you predict you'll need tomorrow.
The cost of speculative features is real: design, code, tests, docs, and the
ongoing tax of every future change touching them. Conversely, a feature not
built costs nothing to maintain and costs little to add later once real
requirements exist.

## When to use

- Planning a feature: a requirement says "maybe users will want to…".
- Implementation: adding a config flag, optional parameter, or endpoint "for flexibility".
- Code review: dead code paths, unused parameters, dormant branches.
- API design: exposing more surface than the current consumer uses.

## How to apply

1. **Anchor to today's requirements**: implement exactly what the current spec demands.
2. **Test the urge**: for any extra piece, ask "is there a user, ticket, or deadline that needs this now?" — no anchor, no build.
3. **Defer with a note**: keep the idea in the backlog or a comment, not in the codebase.
4. **When the need actually arrives**, you'll have real context to design it properly — usually simpler than the guess.

## Anti-patterns

- **Parameter for flexibility**: `process(data, mode="strict")` where nothing passes `"loose"`.
- **Configuration plumbing**: env vars, feature flags, or settings toggling behavior no one uses.
- **Belt-and-suspenders error handling**: branches and retries for failure modes that can't occur.
- **The "just in case" interface**: abstraction layers with a single implementation and no second consumer.

## Example

Bad — 90% of users need upload; "export to PDF" is a someday idea:

```python
class Document:  # 400 lines: upload, versioning, comments, export, sharing…
```

Good — ship the requirement, rest is history:

```python
class Document:  # upload + metadata only
```

When export becomes a funded requirement, design it against real needs.

## Cost accounting

Every speculative line has: implementation cost + test cost + documentation cost
+ the risk of blocking or conflicting with future real needs. The deferred
feature, added later with real requirements, usually costs *less* than the
guess would have. When in doubt, cut it.
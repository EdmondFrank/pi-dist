---
name: dry-principle
description: >
  Apply DRY (Don't Repeat Yourself) when copying code, duplicating logic,
  repeating constants or configs, or copy-pasting the same block in multiple
  places. Use during implementation, refactoring, and code review to extract
  single sources of truth for knowledge and behavior.
---

# DRY — Don't Repeat Yourself

## Core idea

Every piece of knowledge must have a single, unambiguous, authoritative
representation in the system. Duplication is the root of drift: when the rule
changes, every copy must change — and one will be missed.

## When to use

- You notice the same logic, expression, or constant appearing in 2+ places.
- Copy-pasting a block to "just make it work", then it will need edits later.
- A rule exists in code, config, docs, and SQL — it should live in one place.
- Code review: duplicate blocks point at extraction opportunities.

## How to apply

1. **Identify the knowledge**: is it behavior (function), data (constant/config),
   or schema (types/DDL)? Each has its natural home.
2. **Extract the smallest shared unit** — a function, constant, template, or
   shared module — and replace the copies with calls.
3. **Unify parameters**: if copies differ only by arguments, the variation belongs
   in callers, not in the body.
4. **Keep repetition of *accidentally-similar* code separate**: only extract when
   the semantics are genuinely shared, not merely similar in shape.

## Anti-patterns

- **Premature extraction**: unifying code that looks alike but means different things — creates coupling between unrelated concerns.
- **The wrong level**: extracting into shared modules before the module boundary is clear; prefer local extraction first.
- **Over-generalization**: parameterizing with flags/booleans until the function is a turing machine. Extract, then keep call sites obvious.
- **Duplication hidden in literals**: magic numbers/strings repeated across files — promote to named constants.

## Example

Bad:

```python
def send_email(user, msg):
    if not user.is_active: raise PermissionError(user.id)
    ...

def send_sms(phone, user, msg):
    if not user.is_active: raise PermissionError(user.id)
    ...
```

Good — one rule, one place:

```python
def ensure_active(user):
    if not user.is_active:
        raise PermissionError(user.id)

def send_email(user, msg):
    ensure_active(user); ...

def send_sms(user, msg):
    ensure_active(user); ...
```

## Trade-off

DRY fights with readability and decoupling. The rule of three helps: extract on the **third** occurrence unless the shared unit is obvious and stable. When extracting harms readability or couples independent layers, prefer a touch of duplication over a wrong abstraction.
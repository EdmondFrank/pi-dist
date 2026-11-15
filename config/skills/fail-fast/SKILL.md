---
name: fail-fast
description: >
  Apply Fail Fast when validating inputs, designing startup procedures,
  handling contract violations, or deciding between early validation and
  silent fallbacks. Use to detect errors at the earliest, cheapest point —
  raise immediately with clear messages instead of degrading silently,
  retrying pointlessly, or failing later far from the root cause.
---

# Fail Fast — Detect Problems Early

## Core idea

Fail as early as possible, as loudly as necessary. An error detected at the
edge (validation, startup, assertion) costs seconds; the same error surfacing
hours later in production costs an incident. Never let a detectable problem
sail through to become a mysterious downstream failure.

## When to use

- Accepting external input (APIs, config, CLI args, user data) — validate before use.
- Program startup: invalid config or unreachable dependencies should abort at boot, not on first request.
- Contract invariants: preconditions, postconditions, internal assertions.
- Choosing error-handling style: default to loud failure unless a fallback is explicitly specified behavior.

## How to apply

1. **Validate at the boundary**: check inputs (type, range, nullness, format) as they enter the system; reject early with a precise message.
2. **Validate config at startup**: boot-time checks fail deployment fast, inside the deploy pipeline, not in production traffic.
3. **Assert invariants**: for conditions that must hold, fail with a message naming the violated invariant rather than letting it cascade.
4. **Surface the root cause**: error messages name the failing value, the expected contract, and the location.
5. **Choose swappable failure semantics deliberately**: fail-fast by default; add graceful degradation only where the product specifies it (degraded UX, rate limits, canary systems).

## Anti-patterns

- **Null/empty defaulting**: silently substituting default values that mask caller bugs.
- **swallow-and-continue**: `except Exception: pass` around code whose failure matters.
- **Deferred validation**: accepting garbage at the edge, crashing in the middle.
- **Unbounded retries**: retrying requests that fail 4xx/validation errors — they will never succeed.
- **Lazy config**: invalid config discovered on first request in production instead of at deploy.

## Example

Bad:

```python
def charge(card, amount):
    # card may be None, amount may be -5 — crash inside the payment SDK later
    return gateway.charge(card.number, amount)
```

Good:

```python
def charge(card, amount):
    if card is None or not card.number:
        raise ValueError("charge: card must have a number, got None")
    if amount <= 0:
        raise ValueError(f"charge: amount must be positive, got {amount}")
    return gateway.charge(card.number, amount)
```

## Fail fast vs. fault tolerance

Fail-fast is for *detectable program errors* (contract violations, bad input,
misconfiguration). Fault tolerance is for *expected infrastructure failures*
(network blips, transient overload). Decide per failure class: programmer
errors die loud; transient infra errors get bounded retries with exponential
backoff and a clearly logged final failure.
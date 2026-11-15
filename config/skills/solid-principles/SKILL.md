---
name: solid-principles
description: >
  Apply the SOLID design principles (SRP, OCP, LSP, ISP, DIP) when designing
  classes, modules, or system architecture. Use when writing object-oriented
  code, refactoring large classes, reviewing pull requests for design quality,
  choosing abstractions, or deciding how components depend on each other.
---

# SOLID — Better Object-Oriented Design

## Quick reference

| Principle | Rule | Detail skill |
|---|---|---|
| **S** Single Responsibility | One class, one reason to change | `srp` |
| **O** Open/Closed | Extend behavior with new code, never modify working code | `open-closed-principle` |
| **L** Liskov Substitution | Subtypes behave like their base type; no surprise overrides | — |
| **I** Interface Segregation | Clients depend only on interfaces they actually use | — |
| **D** Dependency Inversion | Depend on abstractions, not concretions | `dependency-inversion-principle` |

## When to use

- Designing new classes or module boundaries.
- Refactoring code with code smells: god classes, shotgun changes, fragile base classes, rigid interfaces.
- Reviewing PRs for design quality — check each principle that applies.

## How to apply

1. **Scan the change surface**: identify classes, interfaces, and dependency edges touched by the work.
2. **Check each principle** against the design, using the detail skills:
   - One responsibility per class → `srp`
   - Change by extension, not modification → `open-closed-principle`
   - Substitution safety for any inheritance → LSP
   - Narrow interfaces per client → ISP
   - High-level code depends on abstractions → `dependency-inversion-principle`
3. **Apply the cheapest fix first**: prefer composition and dependency injection over adding abstraction layers.
4. **Re-evaluate**: if the design gains complexity without a concrete benefit, drop the principle — SOLID serves maintainability, not dogma.

## Anti-patterns

- **Over-abstraction**: adding interfaces for every class with no second implementation.
- **Principle theater**: splitting classes to look SOLID while coupling them via hidden global state.
- **LSP violations**: overrides that throw, return `null`, or change invariants.
- **Dependency inversion without injection**: depending on abstractions but constructing concretions inside.

## Example

Bad: `EmailReport` formats data, fetches it from a database, sends it, and logs to file — four reasons to change, all coupled.

Good: split into `ReportFormatter`, `ReportRepository` (depends on `ReportSource` interface), `ReportSender` (depends on `Notifier` interface), `Logger`. Each is a pluggable unit; tests swap fakes without touching production code.
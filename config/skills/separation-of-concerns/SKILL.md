---
name: separation-of-concerns
description: >
  Apply Separation of Concerns when structuring systems, files, layers, or
  packages so that each distinct concern (HTTP handling, business rules,
  persistence, presentation, config) lives in its own place. Use when laying
  out project structure, splitting monoliths, extracting layers, reviewing
  tangled modules, or organizing large refactors. Complements srp at the
  unit level.
---

# Separation of Concerns — Cleaner Design

## Core idea

Distinct concerns — what the system does, how it stores data, how it talks to
the world — belong in distinct, non-tangled places. Each part of the system
can then be understood, tested, and changed independently.

## Concerns to separate

| Concern | Layer |
|---|---|
| HTTP/API/transport | controllers, routers, gateways |
| Business rules / domain | domain models, services |
| Data access / persistence | repositories, DAOs |
| Presentation / output | templates, renderers, views |
| Configuration / wiring | config, composition root |

## When to use

- A module mixes SQL with HTTP responses and UI strings.
- Changing one concern (e.g. DB schema) forces edits across the whole codebase.
- Tests must spin up the full stack to exercise one business rule.
- Laying out a new project: decide the boundary scheme first.

## How to apply

1. **Start at the boundaries**: define the seams between concerns (interface + contract), e.g. repository interfaces, service APIs.
2. **Group by axis**: organize code by concern plane (layers) and/or by feature; pick one dominant axis per codebase and stay consistent.
3. **Route through seam contracts**: cross-boundary calls go through interfaces/APIs, not by reaching into another concern's internals (see `dependency-inversion-principle`).
4. **Keep concerns vertical**: a change to one concern should require edits in one place — verify with "where would I change X?".
5. **Extract gradually**: pull one concern out of a tangle at a time, keeping tests green between extractions.

## Anti-patterns

- **God modules**: one file/module owning HTTP, logic, and DB.
- **Layered soup**: every domain class gets a controller, service, repository, and DTO regardless of need (see `yagni-principle`).
- **Leaking across seams**: SQL in templates, business rules in controllers, config scattered as literals.
- **Themed-but-tangled packages**: folders named by concern that still import each other freely.

## Example

Bad:

```python
@app.post("/orders")
def create_order(request):           # transport + logic + persistence
    data = request.json
    conn = mysql.connect(...)
    conn.execute("INSERT INTO orders …", data)
    send_email(...)                  # transport again
    return render_template("ok.html", …)   # presentation
```

Good:

```python
# web layer:          router → controller (parse request, map to DTO, call service, render)
# domain layer:       OrderService.place_order(cart)  — pure business rules
# persistence layer:  OrderRepository.save(order)     — via interface seam
# notification:       OrderNotifier.confirmation(order)
```

## Relation to other principles

- SRP is the same idea at class/function granularity.
- Separation defines the seams; `dependency-inversion-principle` wires them; `open-closed-principle` keeps them stable while features grow.
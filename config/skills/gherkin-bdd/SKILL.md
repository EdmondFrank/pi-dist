---
name: gherkin-bdd
description: "Gherkin syntax and BDD best practices from cucumber.io/docs. Use when writing feature files, acceptance criteria, scenario outlines, or applying declarative BDD style to executable specifications."
---

# Gherkin & BDD Skill
**Source**: [cucumber.io/docs](https://cucumber.io/docs/) | **Gherkin**: v6+ | **Updated**: 2026-07-23

## How to Use This Skill

- **Writing features** — ask me to write a `.feature` file for a requirement
- **Reviewing scenarios** — ask me to review existing Gherkin for anti-patterns
- **Syntax questions** — ask about keywords, data tables, doc strings, tags, outlines
- **BDD coaching** — ask how to make scenarios more declarative or maintainable

---

## Core Syntax Reference

### File Structure

```gherkin
# language: en
@feature-tag
Feature: Short feature name
  Free-form description (ignored at runtime, used in reports).
  Can span multiple lines and use Markdown.

  Background:
    Given a shared precondition

  @scenario-tag
  Scenario: Concrete example name
    Given an initial context
    When an event occurs
    Then an expected outcome
```

- One `Feature` per `.feature` file
- Indentation: 2 spaces recommended
- Comments: `#` at start of line (no block comments)
- Language header: `# language: <code>` on first line (default: `en`)

### Primary Keywords

| Keyword | Alias | Purpose |
|---------|-------|---------|
| `Feature:` | — | High-level description, groups scenarios |
| `Rule:` | — | Groups scenarios by business rule (Gherkin 6+) |
| `Example:` | `Scenario:` | A concrete test case |
| `Background:` | — | Shared Given steps run before each scenario |
| `Scenario Outline:` | `Scenario Template:` | Parameterized scenario template |
| `Examples:` | `Scenarios:` | Data table for Scenario Outline |

### Step Keywords

| Keyword | Role |
|---------|------|
| `Given` | Initial context / precondition (past tense) |
| `When` | Event or action (the trigger) |
| `Then` | Expected observable outcome (assertion) |
| `And` / `But` | Continuation of Given/When/Then |
| `*` | Bullet-point style, replaces any step keyword |

**Key rule**: Keywords are NOT part of step matching. `Given X` and `Then X` match the same step definition — avoid identical step text across keywords.

### Secondary Keywords

| Symbol | Name | Usage |
|--------|------|-------|
| `"""` or ` ``` ` | Doc String | Multi-line text argument |
| `\|` | Data Table | Tabular data argument |
| `@` | Tag | Metadata for filtering/hooks |
| `#` | Comment | Line comment |

---

## Step Arguments

### Doc Strings

Pass large text blocks to a step. Indentation inside delimiters is preserved relative to the opening delimiter.

```gherkin
Given a blog post named "Random" with Markdown body
  """markdown
  # Some Title
  Here is the first paragraph.
  """
```

- Delimiters: `"""` (standard) or ` ``` ` (Markdown-familiar)
- Optional content type after opening delimiter: `"""json`, `"""markdown`
- Passed as the **last argument** to the step definition automatically

### Data Tables

Pass structured tabular data to a step.

```gherkin
Given the following users exist:
  | name   | email              | twitter          |
  | Aslak  | [email protected] | @aslak_hellesoy  |
  | Julien | [email protected] | @jbpros          |
```

- Passed as the **last argument** to the step definition
- Cell escaping: `\n` (newline), `\|` (pipe), `\\` (backslash)

---

## Scenario Outline (Parameterized Tests)

Run the same scenario with different data combinations:

```gherkin
Scenario Outline: eating cucumbers
  Given there are <start> cucumbers
  When I eat <eat> cucumbers
  Then I should have <left> cucumbers

  Examples:
    | start | eat | left |
    |    12 |   5 |    7 |
    |    20 |   5 |   15 |
```

- `<param>` placeholders reference column headers in `Examples:`
- Runs once per data row (header row excluded)
- Parameters work in step text, descriptions, and doc strings
- Multiple `Examples:` blocks allowed (e.g., tagged subsets)

---

## Background

Shared setup steps run before **every** scenario in the Feature (or Rule):

```gherkin
Feature: Multiple site support
  Background:
    Given a global administrator named "Greg"
    And a blog named "Greg's anti-tax rants"

  Scenario: Admin posts to any blog
    Given I am logged in as Greg
    When I try to post to "Expensive Therapy"
    Then I should see "Your article was published."
```

**Rules**:
- Only ONE Background per Feature or Rule
- Place before the first Scenario/Example
- Keep ≤ 4 lines; use higher-level steps for complex setup
- Use vivid names — tell a story, not "User A / User B"

---

## Rule (Business Rule Grouping)

```gherkin
Feature: Highlander

  Rule: There can be only One
    Example: Only One -- More than one alive
      Given there are 3 ninjas
      When 2 ninjas meet, they will fight
      Then one ninja dies

  Rule: There can be Two (in some cases)
    Example: Dead and Reborn as Phoenix
      ...
```

- Groups scenarios under a named business rule
- Can have its own `Background:`
- Improves traceability: rule → scenarios → steps

---

## Tags

```gherkin
@smoke @fast
Feature: Login

  @wip @issue-123
  Scenario: Valid login
    ...
```

- Prefix with `@`, placed on the line above the element
- Inherit downward: Feature tags apply to all its scenarios
- Use for: filtering execution, hook targeting, reporting categories
- Common patterns: `@wip`, `@smoke`, `@regression`, `@issue-<id>`

---

## BDD Best Practices

### 1. Describe Behaviour, Not Implementation

```gherkin
# ✅ Good — declarative, resilient
When "Bob" logs in

# ❌ Bad — imperative, brittle
Given I visit "/login"
When I enter "Bob" in the "user name" field
And I enter "tester" in the "password" field
And I press the "login" button
Then I should see the "welcome" page
```

**Litmus test**: "Will this wording need to change if the implementation does?" If yes → rework it.

### 2. Prefer Declarative Style

```gherkin
# ✅ Declarative
Given Free Frieda has a free subscription
When Free Frieda logs in with her valid credentials
Then she sees a Free article

# ❌ Imperative (tied to UI mechanics)
Given I am on the login page
When I type "[email protected]" in the email field
And I type "validPassword123" in the password field
And I press the "Submit" button
Then I see "FreeArticle1" on the home page
```

### 3. Keep Scenarios Focused

- **3–5 steps** per scenario (recommended max)
- One behaviour per scenario
- If steps scroll off screen → split or use higher-level steps

### 4. Given = Preconditions, Not Interactions

- Put system in a known state
- Avoid UI actions in Given steps
- Think: "What must be true before the event?"

### 5. Then = Observable Outcomes Only

- Assert on outputs visible to users/external systems
- **Never** assert on database records directly
- Think: reports, UI messages, API responses, notifications

### 6. When = The Single Event

- One action or trigger per scenario (ideally)
- Hide technology: imagine it's 1922, no computers
- Implementation details belong in step definitions

---

## Anti-Patterns

| Anti-Pattern | Problem | Fix |
|---|---|---|
| UI-specific steps ("click button X") | Brittle on UI changes | Declarative: `When Bob logs in` |
| >5 steps per scenario | Loses expressive power | Split or abstract |
| Identical step text with different keywords | Ambiguous matching | Rephrase for clarity |
| Database assertions in Then | Not observable to user | Assert on UI/API output |
| Huge Background (>4 lines) | Reader loses context | Higher-level steps or split Features |
| Scenario Outline with 1 row | Unnecessary indirection | Use plain Scenario |
| No tags | Can't filter/prioritize | Add `@smoke`, `@wip`, etc. |
| Implementation in Feature description | Couples docs to code | Describe business value |

---

## Localization

Gherkin supports 70+ languages. Set via header:

```gherkin
# language: zh-CN
功能: 猜词游戏
  场景: 出题者开始游戏
    当 出题者开始一个游戏
    那么 出题者等待猜词者加入
```

Common codes: `en`, `fr`, `de`, `zh-CN`, `ja`, `no`, `ru`, `es`, `pt`

---

## Quick Template

```gherkin
@feature-area
Feature: [Capability name]
  [Why this feature exists — business value]
  [Key business rules as bullet points]

  Background:
    Given [shared context ≤ 4 lines]

  Rule: [Business rule name]

    @happy-path
    Scenario: [Behaviour name — who does what]
      Given [precondition]
      When [single event/action]
      Then [observable outcome]

    @edge-case
    Scenario Outline: [Parameterized behaviour]
      Given [context with <param>]
      When [event with <param>]
      Then [outcome with <param>]

      Examples:
        | param1 | param2 | expected |
        | val1   | val2   | result1  |
```

---

## Step Definition Matching (Implementation Side)

- Steps matched by **text pattern** (regex or expression), NOT by keyword
- Doc Strings and Data Tables arrive as the **last argument**
- Hooks (`Before`/`After`) run around scenarios; Background runs after `Before` hooks
- Tag expressions: `@smoke and not @wip` for selective execution

---

## Checklist: Writing a Good Feature File

- [ ] One Feature per file, named after the capability
- [ ] Free-form description explains business value
- [ ] Tags for filtering (`@smoke`, `@wip`, `@regression`)
- [ ] Background ≤ 4 lines with vivid names
- [ ] Scenarios: 3–5 steps, one behaviour each
- [ ] Given = state, When = event, Then = observable outcome
- [ ] No UI/implementation details in step text
- [ ] Data Tables for structured inputs
- [ ] Scenario Outline for repeated patterns with varying data
- [ ] Rule blocks for distinct business rules

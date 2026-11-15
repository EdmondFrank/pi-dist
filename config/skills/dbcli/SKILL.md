---
name: dbcli
description: Access and operate any database via CLI. Use when exploring schemas, querying data, writing records, running migrations, diagnosing connection issues, or switching between multiple databases. Supports SQLite, PostgreSQL, MySQL, MariaDB, DuckDB, ClickHouse, and SQL Server.
---

# dbcli

## Overview

Database CLI for AI agents. Stateless, token-efficient, multi-database. Use shell commands instead of MCP tools — zero context cost.

## Quick Start

```bash
# Connect
dbcli connect mydata.db
dbcli connect "postgresql://user:pass@host/db" --as prod

# Explore
dbcli tables
dbcli schema
dbcli describe users

# Query
dbcli q "SELECT * FROM users LIMIT 10"

# Write
dbcli exec "INSERT INTO users (name) VALUES ('Alice')"
```

## Workflows

### 1. Explore an unknown database

```bash
dbcli connect <url> --as <alias>
dbcli tables
dbcli schema
dbcli fks <table>
dbcli sample <table> 5
```

Read the schema output first. Identify primary keys, foreign keys, and column types before writing any query.

### 2. Query data

```bash
dbcli q "SELECT * FROM users WHERE active = 1"
dbcli q "SELECT * FROM users" -f json
dbcli q "SELECT * FROM users" -f jsonl
dbcli q "SELECT * FROM users" -f tsv
dbcli count users
dbcli count users "age > 18"
dbcli sample users 10
```

Default LIMIT is 100. Use `--limit 0` only when you need all rows and are sure the result set is bounded.

### 3. Write data

```bash
dbcli exec "INSERT INTO users (name, email) VALUES ('Alice', 'alice@example.com')"
dbcli exec "UPDATE users SET active = 0 WHERE last_login < '2024-01-01'"
dbcli exec "DELETE FROM users WHERE id = 42"
dbcli exec-file migrations/001_create_tables.sql
```

Every write command returns `affected:N`. Verify the count matches expectations before proceeding.

### 4. Switch between databases

```bash
dbcli connect prod.db --as prod
dbcli connect staging.db --as staging
dbcli use prod
dbcli status
dbcli use staging
```

Always run `dbcli status` after switching to confirm the active connection.

### 5. Diagnose and analyze

```bash
dbcli audit                     # find missing PKs, phantom FKs, empty tables
dbcli explain "SELECT ..."      # compact query plan
dbcli erd                       # entity-relationship map
dbcli describe <table>          # row count, indexes, FKs
dbcli profile <table>           # column-level data profiling
dbcli snap                      # full DB context in one command
```

`audit` output example:
```
no_pk:orphan_table
empty:orphan_table
phantom_fk:reviews.user_id->users
```

`erd` output example:
```
orders(id, user_id, product, amount) [2]
users(id, name, email, age) [5]
---
users -< orders.user_id
```

### 6. Compare schemas (migrations, staging vs prod)

```bash
dbcli connect prod.db --as prod
dbcli connect staging.db --as staging
dbcli diff --from prod --to staging
```

Output:
```
+payments(id:INTEGER PK, order_id:INTEGER, method:TEXT)
-old_table(val:TEXT)
~users: +role:TEXT, -legacy_col
```

`+` = added, `-` = removed, `~` = changed.

### 7. Profile data and get full context

```bash
# Profile a single table — shows per-column stats
dbcli profile users
# rows:5
# name:TEXT distinct=4 nulls=0 sample=[Alice,Bob,Charlie]
# age:INTEGER distinct=4 nulls=1 min=18 max=65 avg=35.5
# role:TEXT distinct=2 nulls=0 values=[admin=2,user=3]

# Full database snapshot — schema + ERD + profiles in one command
dbcli snap
# users(id:INTEGER PK, name:TEXT, age:INTEGER) [5]
#   name:TEXT distinct=4 nulls=0 sample=[Alice,Bob,Charlie]
#   age:INTEGER distinct=4 nulls=1 min=18 max=65 avg=35.5
# orders(id:INTEGER PK, user_id:INTEGER FK->users.id, amount:REAL) [12]
#   user_id:INTEGER distinct=3 nulls=0 values=[1=5,2=4,3=3]
#   amount:REAL distinct=10 nulls=0 min=9.99 max=299.99 avg=87.50
# ---
# users -< orders.user_id
```

Use `dbcli snap` as the first command on any new database — it gives full context in one call instead of 5-10 separate commands.

## Command Reference

| Command | Output | Purpose |
|---------|--------|---------|
| `connect <url> [--as alias]` | `connected:<alias>` | Connect to database |
| `use <alias>` | `active:<alias>` | Switch connection |
| `status` | `alias\|driver\|url` | Show active connection |
| `tables` | one per line | List tables |
| `schema [table]` | compact notation | Show structure |
| `describe <table>` | key:value lines | Rows, indexes, FKs |
| `indexes <table>` | one per line | List indexes |
| `fks <table>` | one per line | List foreign keys |
| `q <sql> [-f fmt]` | csv/json/jsonl/tsv | Query data |
| `sample <table> [N]` | like query | Random rows (default 5) |
| `count <table> [where]` | number | Count rows |
| `exec <sql>` | `affected:N` | Execute statement |
| `exec-file <path>` | `affected:N` | Execute SQL file |
| `explain <sql>` | plan lines | Query execution plan |
| `audit` | issue per line | Find structural problems |
| `erd` | compact diagram | Entity-relationship map |
| `diff --from a --to b` | `+/-/~` lines | Compare schemas |
| `profile <table>` | per-column stats | Data profiling |
| `snap` | schema+erd+profiles | Full DB context |

## Supported Databases

| Database | URL format |
|----------|------------|
| SQLite | `mydata.db` |
| PostgreSQL | `postgresql://user:pass@host:5432/db` |
| MySQL | `mysql://user:pass@host:3306/db` |
| MariaDB | `mariadb://user:pass@host:3306/db` |
| DuckDB | `file.duckdb` |
| ClickHouse | `clickhouse://user:pass@host:8123/db` |
| SQL Server | `mssql://user:pass@host:1433/db` |

Supabase, Neon, and CockroachDB work with the PostgreSQL URL format.

## Output Rules

- Errors go to stderr: `error:<type>|<message>` — stdout is always clean.
- Exit codes: 0=ok, 1=sql_error, 2=conn_error, 3=no_conn, 4=not_found, 5=usage.
- Schema is compact: `users(id:INTEGER PK, name:TEXT, email:TEXT FK->accounts.email)`.
- CSV is the default query format. Use `-f json` when structured parsing is needed.

## Operating Rules

- Use `dbcli snap` as the first command when exploring any new database — it replaces schema + erd + profile in one call.
- Always run `dbcli schema` before writing queries against an unfamiliar database.
- Always check `affected:N` after write operations.
- Prefer `dbcli q` over `dbcli query` — shorter, same behavior.
- Use `--limit 0` sparingly — large result sets waste context.
- Use `-f json` when piping output to other tools.
- Use `DBCLI_URL` env var in CI/CD instead of `dbcli connect`.

## Common Mistakes

- Querying without connecting first — run `dbcli connect` or set `DBCLI_URL`.
- Forgetting that LIMIT 100 is applied by default — use `--limit 0` if you need all rows.
- Using `exec` for SELECT — use `q` instead; `exec` returns only `affected:N`.
- Splitting multi-word SQL without quotes — wrap SQL in double quotes: `dbcli q "SELECT * FROM users"`.

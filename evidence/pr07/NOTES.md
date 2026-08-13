# PR07 — Indexer evidence notes

## Summary

Implemented `LociIndex` with **GRDB 7.x** (builds on Swift 6.2 Linux + Apple). Local SQLite projection under Application Support–style directories / temp dirs for tests — **never inside the vault**.

## Schema (`<directory>/<vaultID>/index.sqlite`)

| Table | Role |
|---|---|
| `objects` | id, type_id, title, created, updated, relative_path, tags_json, properties_json |
| `links` | source_id → wiki-link target/label |
| `tags` | (object_id, tag) |
| `properties_idx` | keyed property scalars for filter/sort (PR13+) |
| `blocks_fts` | FTS5 (object_id UNINDEXED, title, body) |

API: `IndexDatabase(vaultID:directory:)` → `…/<vaultID>/index.sqlite`

## Critical guardrail

**Confirmed:** after unit tests and `loci-index-demo`, **no `index.sqlite` exists under the vault path**.

- Test: `testNoIndexSqliteInsideVaultAfterIndexing`
- Demo JSON: `"indexInsideVault": false`
- Harness Search panel shows `Index inside vault? no ✓`

## Tests

- **73** package tests (was 66) — +9 IndexService tests, −2 stub tests
- Lint + build green
- Harness: `http://127.0.0.1:5173/?panel=search`

## Artifacts

| File | Meaning |
|---|---|
| `test.log` | `./scripts/test.sh` |
| `lint.log` | `./scripts/lint.sh` |
| `demo-index.log` | `./scripts/demo-index.sh` |
| `search.json` | exported IndexQuerying fixture |
| `harness-search.png` | Search panel screenshot |
| `harness-search-dom.html` | rendered DOM |
| `harness.log` | chrome + HTTP checks |

## SQLite choice

Tried GRDB on Linux first — **compiles and FTS5 works**. Pinned via SPM `from: "7.0.0"` (resolved **7.11.1** in `Package.resolved`).

**System package:** `libsqlite3-dev` required on Ubuntu for GRDB link (headers + `.so`). Runtime `libsqlite3-0` alone is not enough for builds.

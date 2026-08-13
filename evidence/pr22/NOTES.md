# PR22 evidence — Collections (Wave C start)

| Check | Result |
|---|---|
| `./scripts/lint.sh` | passed (`evidence/pr22/lint.log`) |
| `./scripts/test.sh` | **194** tests, 0 failures (`evidence/pr22/test.log`) — was 189 on PR21 |
| `./scripts/demo-collections.sh` | passed — Favorites membership vault file (`demo.log`, `collections.json`) |
| DevHarness `?panel=types` | served; DOM + screenshot (`harness-types-dom.html`, `harness-types.png`) |

## Demo proof

- Membership file `.loci/collections/book.favorites.json` exists (`favorites.exists`)
- Favorites has 2 members; All has 3 books; Reading List separate collection
- Tabs: All / Favorites / Reading List
- Index not inside vault (`indexInsideVault=false`, `membershipIsVaultFile=true`)

## Handoff

Next: **PR23 Saved queries + embeds** — QueryEngine DSL; save query objects; pin to dashboard; `/query` embed block.

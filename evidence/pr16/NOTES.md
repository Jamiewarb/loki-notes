# PR16 — Wiki-links and backlinks

## Summary

**LinkResolver** resolves wiki-link targets with ObjectID first, then path/slug, then title. `@` / `[[` picker inserts `[[id|title]]` into the editor. **Backlinks panel** in the object inspector reads the disposable `links` index table. Broken targets get `is-broken` styling (danger + dashed underline).

## Demo proof

| Check | Result |
|---|---|
| Page A → Page B via `[[ObjectID\|title]]` | `proof.aLinksToB=true` |
| Open B → backlink to A | `backlinkCount=1` |
| Broken outgoing styled | `brokenCount=1` · `wiki-link is-broken` |
| Preferred target is ObjectID | `preferredTargetIsObjectID=true` |
| Index outside vault | `indexInsideVault=false` |

## What landed

| Piece | Location |
|---|---|
| `LinkResolver` + `LinksQuery` | `LociIndex/Queries/` |
| `IndexQuerying` resolve/backlinks/outgoing/candidates | `LociCore` |
| `@` / `[[` trigger + `insertWikiLink` | `LociMarkdown` |
| `Features/Links/` picker + backlinks + status | `App/Features/Links/` |
| Inspector wiring | `InspectorHostView` (properties + backlinks) |
| Editor picker + broken chips | `BlockEditorView` / `EditorSessionBridge` |
| Demo | `loci-links-demo` + `scripts/demo-links.sh` |
| Harness | Studio → Links (`?panel=links`) |
| Version | `LociIndex` / `LociMarkdown` / `LociVault` → `*-pr16` |

## Design choices

1. **Identity-first links** — picker always writes ObjectID; path/slug/title resolve for legacy / Obsidian-style targets.
2. **Backlinks are index-only** — never rewritten into markdown automatically.
3. **Broken styling** — danger color + dashed underline (`is-broken`); resolved uses accent.
4. **Skipped:** Project `area` → object-select (scope creep; clean follow-up once tags land).

## Tests

- **139** package tests (was 127) — all green
- New: `WikiLinksAndBacklinksTests` (5), `WikiLinkTriggerAndInsertTests` (7)

## Harness

- `http://127.0.0.1:5173/?panel=links` — A→B proof, backlinks list, broken styling, picker candidates
- Artifacts: `harness-links.png`, `harness-links-dom.html`, `links.json`

## Notes for PR17 (Tags)

- `#tag` already parses in Loci MD + indexes into `tags` table
- Need object-level tags UI, tag browse view, aliases, dashboard filter
- Backlinks panel pattern is a good template for a Tags inspector section
- Do not put SQLite / index inside the vault

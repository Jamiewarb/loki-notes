# DevHarness

Browser-runnable **visual test shell** for Loci Cloud agents (no Xcode / Simulator required).

## Run

```bash
./scripts/run-harness.sh
# → http://127.0.0.1:5173
```

## What it mirrors

- Brand **Loci** as a hero-level signal in chrome
- CSS variables aligned with `LociDesignSystem` tokens (`--loci-ink`, `--loci-accent`, …)
- **Design** gallery panel (PR02) — colors, type, spacing, button/field/row/empty primitives, motion
- Sidebar: Design, Daily, Search, Types, Settings
- Detail + inspector placeholders for AppShell (PR03)
- **Daily** panel (PR10/PR11) — today’s note + Created today from `public/demo-daily/` + `public/demo-created-today/` (`?panel=daily`); `./scripts/demo-daily.sh` + `./scripts/demo-created-today.sh`
- **Settings** vault status panel (PR04) — localDocuments copy + Create vault instructions (`?panel=settings`)
- **Types** schema panel (PR05/PR12/PR13/PR14) — loads `public/demo-types/` + `public/demo-schema/` + `public/demo-templates/` (`?panel=types`); generate with `./scripts/demo-templates.sh`
- **Markdown** debug panel (PR06) — `?panel=markdown`; `./scripts/demo-markdown.sh`
- **Search** index panel (PR18) — FTS title+body hits grouped by type from `public/demo-search/search.json` (`?panel=search`); `./scripts/demo-search.sh` (optional `LOCI_SEARCH_BULK=1000`)
- **Editor** panel (PR09) — BlockAST slash simulation (`?panel=editor`); `./scripts/demo-editor.sh`
- CLI proof: `./scripts/demo-vault.sh` / `./scripts/demo-schema.sh` / `./scripts/demo-markdown.sh` / `./scripts/demo-index.sh` / `./scripts/demo-objects.sh` / `./scripts/demo-editor.sh` / `./scripts/demo-daily.sh` / `./scripts/demo-created-today.sh` / `./scripts/demo-types.sh` / `./scripts/demo-properties.sh` / `./scripts/demo-templates.sh`

## Adding a panel in a later PR

1. Add `src/panels/<Feature>Panel.ts` (or extend `PANELS` in `src/shell.ts`).
2. Register a nav item if the feature needs a destination.
3. Keep one job per panel; avoid stuffing MVP UI into the harness.
4. Capture evidence under `evidence/prNN/` (curl HTML and/or screenshot).

This harness does **not** replace Swift unit tests (`scripts/test.sh`).

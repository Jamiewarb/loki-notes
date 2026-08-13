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
- **Daily** panel (PR10) — today’s note fixture from `public/demo-daily/` (`?panel=daily`); generate with `./scripts/demo-daily.sh`
- **Settings** vault status panel (PR04) — localDocuments copy + Create vault instructions (`?panel=settings`)
- **Types** schema panel (PR05) — loads `public/demo-schema/` fixtures (`?panel=types`); generate with `./scripts/demo-schema.sh`
- **Markdown** debug panel (PR06) — `?panel=markdown`; `./scripts/demo-markdown.sh`
- **Search** index panel (PR07) — FTS + created(on:) from `public/demo-index/search.json` (`?panel=search`); `./scripts/demo-index.sh`
- **Editor** panel (PR09) — BlockAST slash simulation (`?panel=editor`); `./scripts/demo-editor.sh`
- CLI proof: `./scripts/demo-vault.sh` / `./scripts/demo-schema.sh` / `./scripts/demo-markdown.sh` / `./scripts/demo-index.sh` / `./scripts/demo-objects.sh` / `./scripts/demo-editor.sh` / `./scripts/demo-daily.sh`

## Adding a panel in a later PR

1. Add `src/panels/<Feature>Panel.ts` (or extend `PANELS` in `src/shell.ts`).
2. Register a nav item if the feature needs a destination.
3. Keep one job per panel; avoid stuffing MVP UI into the harness.
4. Capture evidence under `evidence/prNN/` (curl HTML and/or screenshot).

This harness does **not** replace Swift unit tests (`scripts/test.sh`).

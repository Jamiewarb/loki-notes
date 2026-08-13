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

## Adding a panel in a later PR

1. Add `src/panels/<Feature>Panel.ts` (or extend `PANELS` in `src/shell.ts`).
2. Register a nav item if the feature needs a destination.
3. Keep one job per panel; avoid stuffing MVP UI into the harness.
4. Capture evidence under `evidence/prNN/` (curl HTML and/or screenshot).

This harness does **not** replace Swift unit tests (`scripts/test.sh`).

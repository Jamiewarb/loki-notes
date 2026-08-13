#!/usr/bin/env bash
# scripts/e2e.sh — Playwright feature tests against DevHarness.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HARNESS="$ROOT/DevHarness"
cd "$HARNESS"

export PATH="${HOME}/.nvm/versions/node/$(ls "${HOME}/.nvm/versions/node" 2>/dev/null | tail -1)/bin:/usr/local/bin:${PATH:-}"

if ! command -v npm >/dev/null 2>&1; then
  echo "error: npm not found. Install Node.js 20+ to run e2e tests." >&2
  exit 1
fi

if [[ ! -d node_modules ]]; then
  echo "==> npm install"
  npm install
fi

echo "==> playwright install chromium"
npx playwright install --with-deps chromium

echo "==> playwright test"
npx playwright test

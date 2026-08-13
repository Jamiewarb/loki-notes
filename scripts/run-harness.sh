#!/usr/bin/env bash
# scripts/run-harness.sh — start DevHarness (Vite) for visual testing.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HARNESS="$ROOT/DevHarness"
cd "$HARNESS"

export PATH="${HOME}/.nvm/versions/node/$(ls "${HOME}/.nvm/versions/node" 2>/dev/null | tail -1)/bin:/usr/local/bin:${PATH:-}"

if ! command -v npm >/dev/null 2>&1; then
  echo "error: npm not found. Install Node.js 20+ to run DevHarness." >&2
  exit 1
fi

if [[ ! -d node_modules ]]; then
  echo "==> npm install"
  npm install
fi

PORT="${LOCI_HARNESS_PORT:-5173}"
HOST="${LOCI_HARNESS_HOST:-127.0.0.1}"

echo "==> DevHarness at http://${HOST}:${PORT}"
echo "    Future PRs: add a panel under DevHarness/src/panels/ and register in src/shell.ts"
exec npx vite --host "$HOST" --port "$PORT"

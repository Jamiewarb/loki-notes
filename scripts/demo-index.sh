#!/usr/bin/env bash
# scripts/demo-index.sh — rebuild sample vault index and copy JSON for DevHarness (PR07).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

export PATH="/opt/swift/usr/bin:${PATH:-}"

if ! command -v swift >/dev/null 2>&1; then
  echo "error: swift not found on PATH. Install toolchain (see AGENTS.md)." >&2
  exit 1
fi

OUT_DIR="$ROOT/DevHarness/public/demo-index"
mkdir -p "$OUT_DIR"

echo "==> loci-index-demo"
swift run --package-path "$ROOT" loci-index-demo > "$OUT_DIR/search.json"

echo "==> wrote $OUT_DIR/search.json"
echo "==> demo-index complete"

#!/usr/bin/env bash
# scripts/demo-objects.sh — ObjectService create/list export for DevHarness Types/Page (PR08).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

export PATH="/opt/swift/usr/bin:${PATH:-}"

if ! command -v swift >/dev/null 2>&1; then
  echo "error: swift not found on PATH. Install toolchain (see AGENTS.md)." >&2
  exit 1
fi

OUT_DIR="$ROOT/DevHarness/public/demo-objects"
mkdir -p "$OUT_DIR"

echo "==> loci-objects-demo"
swift run --package-path "$ROOT" loci-objects-demo > "$OUT_DIR/pages.json"

echo "==> wrote $OUT_DIR/pages.json"
echo "==> demo-objects complete"

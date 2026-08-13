#!/usr/bin/env bash
# scripts/demo-markdown.sh — round-trip sample MD and copy JSON for DevHarness (PR06).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

export PATH="/opt/swift/usr/bin:${PATH:-}"

if ! command -v swift >/dev/null 2>&1; then
  echo "error: swift not found on PATH. Install toolchain (see AGENTS.md)." >&2
  exit 1
fi

OUT_DIR="$ROOT/DevHarness/public/demo-markdown"
mkdir -p "$OUT_DIR"

echo "==> loci-markdown-demo"
swift run --package-path "$ROOT" loci-markdown-demo > "$OUT_DIR/roundtrip.json"

# Also copy a canonical fixture for the harness to display raw source.
cp "$ROOT/LociMarkdown/Tests/LociMarkdownTests/Fixtures/basic-page.md" "$OUT_DIR/basic-page.md"

echo "==> wrote $OUT_DIR/roundtrip.json"
echo "==> wrote $OUT_DIR/basic-page.md"
echo "==> demo-markdown complete"

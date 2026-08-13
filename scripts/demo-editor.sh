#!/usr/bin/env bash
# scripts/demo-editor.sh — EditorSession slash simulation + HTML AST for DevHarness (PR09).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

export PATH="/opt/swift/usr/bin:${PATH:-}"

if ! command -v swift >/dev/null 2>&1; then
  echo "error: swift not found on PATH. Install toolchain (see AGENTS.md)." >&2
  exit 1
fi

OUT_DIR="$ROOT/DevHarness/public/demo-editor"
mkdir -p "$OUT_DIR"

echo "==> loci-editor-demo"
swift run --package-path "$ROOT" loci-editor-demo > "$OUT_DIR/editor.json"

# Extract HTML fragment for direct harness fetch
python3 - <<'PY'
import json, pathlib
root = pathlib.Path("DevHarness/public/demo-editor")
data = json.loads((root / "editor.json").read_text())
(root / "ast.html").write_text(data.get("html", ""))
(root / "serialized.md").write_text(data.get("serialized", ""))
print(f"blocks={data.get('blockCount')} stable={data.get('roundTripStable')}")
PY

echo "==> wrote $OUT_DIR/editor.json"
echo "==> wrote $OUT_DIR/ast.html"
echo "==> wrote $OUT_DIR/serialized.md"
echo "==> demo-editor complete"

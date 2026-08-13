#!/usr/bin/env bash
# scripts/demo-created-today.sh — Created-today index panel fixture for DevHarness (PR11).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

export PATH="/opt/swift/usr/bin:${PATH:-}"

if ! command -v swift >/dev/null 2>&1; then
  echo "error: swift not found on PATH. Install toolchain (see AGENTS.md)." >&2
  exit 1
fi

OUT_DIR="$ROOT/DevHarness/public/demo-created-today"
mkdir -p "$OUT_DIR"

echo "==> loci-created-today-demo"
swift run --package-path "$ROOT" loci-created-today-demo > "$OUT_DIR/created-today.json"

python3 - <<'PY'
import json, pathlib
root = pathlib.Path("DevHarness/public/demo-created-today")
data = json.loads((root / "created-today.json").read_text())
(root / "today.md").write_text(data.get("markdown", ""))
proof = data.get("proof", {})
items = data.get("createdToday", [])
print(
    f"dailyUnchanged={proof.get('dailyUnchanged')} "
    f"createdToday={len(items)} "
    f"hash={proof.get('beforeHash', '')[:12]}…"
)
if not proof.get("dailyUnchanged"):
    raise SystemExit("FAIL: daily .md changed after Page create")
PY

echo "==> wrote $OUT_DIR/created-today.json"
echo "==> wrote $OUT_DIR/today.md"
echo "==> demo-created-today complete"

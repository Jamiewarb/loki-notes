#!/usr/bin/env bash
# scripts/demo-daily.sh — DailyNoteService ensure today + fixture for DevHarness (PR10).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

export PATH="/opt/swift/usr/bin:${PATH:-}"

if ! command -v swift >/dev/null 2>&1; then
  echo "error: swift not found on PATH. Install toolchain (see AGENTS.md)." >&2
  exit 1
fi

OUT_DIR="$ROOT/DevHarness/public/demo-daily"
mkdir -p "$OUT_DIR"

echo "==> loci-daily-demo"
swift run --package-path "$ROOT" loci-daily-demo > "$OUT_DIR/daily.json"

python3 - <<'PY'
import json, pathlib
root = pathlib.Path("DevHarness/public/demo-daily")
data = json.loads((root / "daily.json").read_text())
(root / "today.md").write_text(data.get("markdown", ""))
scheme = data.get("scheme", {})
print(
    f"path={scheme.get('examplePath')} id={scheme.get('exampleId')} "
    f"idempotent={data.get('idempotent')}"
)
PY

echo "==> wrote $OUT_DIR/daily.json"
echo "==> wrote $OUT_DIR/today.md"
echo "==> demo-daily complete"

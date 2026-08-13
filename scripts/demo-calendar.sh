#!/usr/bin/env bash
# scripts/demo-calendar.sh — Calendar fixtures for DevHarness (PR25).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

export PATH="/opt/swift/usr/bin:${PATH:-}"

if ! command -v swift >/dev/null 2>&1; then
  echo "error: swift not found on PATH. Install toolchain (see AGENTS.md)." >&2
  exit 1
fi

OUT_DIR="$ROOT/DevHarness/public/demo-calendar"
mkdir -p "$OUT_DIR"

echo "==> loci-calendar-demo"
swift run --package-path "$ROOT" loci-calendar-demo > "$OUT_DIR/calendar.json"

python3 - <<'PY'
import json, pathlib
root = pathlib.Path("DevHarness/public/demo-calendar")
data = json.loads((root / "calendar.json").read_text())
assert data.get("indexInsideVault") is False, "index must not live in vault"
month = data.get("month") or {}
assert month.get("cellCount") == 42, month
assert month.get("markedDayCount", 0) >= 2, month
week = data.get("week") or {}
assert week.get("cellCount") == 7, week
proof = data.get("proof") or {}
assert proof.get("day13HasDailyAndContent") is True, proof
assert proof.get("day13HasCreations") is True, proof
assert proof.get("day14HasDailyAfterJump") is True, proof
assert proof.get("chromeDidNotRewriteDaily13") is True, proof
assert proof.get("monthCellCount42") is True, proof
assert proof.get("weekCellCount7") is True, proof
jump = data.get("jump") or {}
assert jump.get("path") == "daily/2026-08-14.md", jump
print(
    f"month={month.get('title')} cells={month.get('cellCount')} "
    f"marked={month.get('markedDayCount')} week={week.get('cellCount')} "
    f"jump={jump.get('path')}"
)
PY

echo "wrote DevHarness/public/demo-calendar/calendar.json"

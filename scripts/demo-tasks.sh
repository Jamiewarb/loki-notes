#!/usr/bin/env bash
# scripts/demo-tasks.sh — Task Today/Open fixtures for DevHarness (PR19).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

export PATH="/opt/swift/usr/bin:${PATH:-}"

if ! command -v swift >/dev/null 2>&1; then
  echo "error: swift not found on PATH. Install toolchain (see AGENTS.md)." >&2
  exit 1
fi

OUT_DIR="$ROOT/DevHarness/public/demo-tasks"
mkdir -p "$OUT_DIR"

echo "==> loci-tasks-demo"
swift run --package-path "$ROOT" loci-tasks-demo > "$OUT_DIR/tasks.json"

python3 - <<'PY'
import json, pathlib
root = pathlib.Path("DevHarness/public/demo-tasks")
data = json.loads((root / "tasks.json").read_text())
proof = data.get("proof") or {}
assert proof.get("pageToggleCompleted") is True, proof
assert proof.get("dailyHasOpen") is True, proof
assert proof.get("indexOutsideVault") is True, proof
assert data.get("indexInsideVault") is False, "index must not live in vault"
assert (proof.get("openCount") or 0) >= 1, proof
assert (proof.get("todayCount") or 0) >= 2, proof
assert any(t.get("text") == "Check task in a Page" and t.get("completed") for t in (data.get("completedTasks") or [])), data
print(
    f"open={proof.get('openCount')} today={proof.get('todayCount')} "
    f"completed={proof.get('completedCount')} pageToggle={proof.get('pageToggleCompleted')} "
    f"indexOutsideVault=True"
)
PY

echo "==> wrote $OUT_DIR/tasks.json"
echo "==> demo-tasks complete"

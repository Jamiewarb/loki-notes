#!/usr/bin/env bash
# scripts/demo-import.sh — Import dry-run/apply fixtures for DevHarness (PR27).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

export PATH="/opt/swift/usr/bin:${PATH:-}"

if ! command -v swift >/dev/null 2>&1; then
  echo "error: swift not found on PATH. Install toolchain (see AGENTS.md)." >&2
  exit 1
fi

OUT_DIR="$ROOT/DevHarness/public/demo-import"
mkdir -p "$OUT_DIR"

echo "==> loci-import-demo"
swift run --package-path "$ROOT" loci-import-demo > "$OUT_DIR/import.json"

python3 - <<'PY'
import json, pathlib
root = pathlib.Path("DevHarness/public/demo-import")
data = json.loads((root / "import.json").read_text())
assert data.get("indexInsideVault") is False, "index must not live in vault"
proof = data.get("proof") or {}
assert proof.get("dryRunBeforeApply") is True, proof
assert proof.get("markdownWrote") is True, proof
assert proof.get("obsidianWrote") is True, proof
assert proof.get("capacitiesWrote") is True, proof
assert proof.get("obsidianDailyPath") is True, proof
assert proof.get("obsidianDailyID") is True, proof
assert proof.get("capacitiesPreservedID") is True, proof
assert proof.get("capacitiesBookType") is True, proof
assert proof.get("markdownMediaCopied") is True, proof
assert proof.get("conflictSkip") is True, proof
assert proof.get("indexOutsideVault") is True, proof
runs = data.get("runs") or []
assert len(runs) == 3, runs
print(
    f"runs={len(runs)} proof_ok={sum(1 for v in proof.values() if v)}/{len(proof)} "
    f"module={data.get('moduleVersion')}"
)
PY

echo "wrote DevHarness/public/demo-import/import.json"

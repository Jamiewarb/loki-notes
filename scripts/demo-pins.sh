#!/usr/bin/env bash
# scripts/demo-pins.sh — pinned objects fixtures for DevHarness (PR34).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

export PATH="/opt/swift/usr/bin:${PATH:-}"

if ! command -v swift >/dev/null 2>&1; then
  echo "error: swift not found on PATH. Install toolchain (see AGENTS.md)." >&2
  exit 1
fi

OUT_DIR="$ROOT/DevHarness/public/demo-pins"
mkdir -p "$OUT_DIR"

echo "==> loci-pins-demo"
swift run --package-path "$ROOT" loci-pins-demo > "$OUT_DIR/pins.json"

python3 - <<'PY'
import json, pathlib
root = pathlib.Path("DevHarness/public/demo-pins")
data = json.loads((root / "pins.json").read_text())
assert data.get("indexInsideVault") is False, "index must not live in vault"
proof = data.get("proof") or {}
assert proof.get("indexInsideVault") is True, proof
assert proof.get("pinsInSpaceJSON") is True, proof
assert proof.get("orderPreserved") is True, proof
assert proof.get("unpinWorked") is True, proof
assert proof.get("idempotentPin") is True, proof
assert proof.get("dailyPinAllowed") is True, proof
assert proof.get("missingPinShown") is True, proof
assert proof.get("clickOpenInHarness") is True, proof
pins = data.get("pins") or []
assert len(pins) >= 2, pins
assert pins[0].get("title") == "Inbox", pins
assert pins[-1].get("isMissing") is True, pins
assert any(p.get("type") == "daily" for p in pins), pins
space = data.get("spacePins") or []
assert len(space) == len(pins), (space, pins)
print(
    f"pins={len(pins)} spacePins={space} "
    f"indexInsideVault={data.get('indexInsideVault')} "
    f"module={data.get('moduleVersion')}"
)
PY

echo "wrote DevHarness/public/demo-pins/pins.json"

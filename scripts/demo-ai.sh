#!/usr/bin/env bash
# scripts/demo-ai.sh — AI assist fixtures for DevHarness (PR30).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

export PATH="/opt/swift/usr/bin:${PATH:-}"

if ! command -v swift >/dev/null 2>&1; then
  echo "error: swift not found on PATH. Install toolchain (see AGENTS.md)." >&2
  exit 1
fi

OUT_DIR="$ROOT/DevHarness/public/demo-ai"
mkdir -p "$OUT_DIR"

echo "==> loci-ai-demo"
swift run --package-path "$ROOT" loci-ai-demo > "$OUT_DIR/ai.json"

python3 - <<'PY'
import json, pathlib
root = pathlib.Path("DevHarness/public/demo-ai")
data = json.loads((root / "ai.json").read_text())
assert data.get("indexInsideVault") is False, "index must not live in vault"
assert data.get("credentialsInsideVault") is False, "credentials must not live in vault"
proof = data.get("proof") or {}
assert proof.get("uploadRefusedWithoutOptIn") is True, proof
assert proof.get("summarize") is True, proof
assert proof.get("rewrite") is True, proof
assert proof.get("translate") is True, proof
assert proof.get("autofill") is True, proof
assert proof.get("applyViaObjectServing") is True, proof
assert proof.get("indexOutsideVault") is True, proof
assert proof.get("credentialsOutsideVault") is True, proof
assert data.get("uploadRefusedWithoutOptIn") is True
summary = (data.get("summarize") or {}).get("summary") or ""
assert summary.startswith("Summary: "), summary
translated = (data.get("translate") or {}).get("proposedBody") or ""
assert "hola" in translated and "loci-ai:translated:es" in translated, translated
print(
    f"summarize={bool(summary)} translate_es={('hola' in translated)} "
    f"uploadRefused={data.get('uploadRefusedWithoutOptIn')} "
    f"module={data.get('moduleVersion')}"
)
PY

echo "wrote DevHarness/public/demo-ai/ai.json"

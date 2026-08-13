#!/usr/bin/env bash
# scripts/demo-weblink-preview.sh — weblink OG preview cache proofs (PR43).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

export PATH="/opt/swift/usr/bin:${PATH:-}"

if ! command -v swift >/dev/null 2>&1; then
  echo "error: swift not found on PATH. Install toolchain (see AGENTS.md)." >&2
  exit 1
fi

OUT_DIR="$ROOT/DevHarness/public/demo-weblink-preview"
mkdir -p "$OUT_DIR"

echo "==> loci-weblink-preview-demo"
swift run --package-path "$ROOT" loci-weblink-preview-demo > "$OUT_DIR/weblink-preview.json"

python3 - <<'PY'
import json, pathlib

root = pathlib.Path("DevHarness/public/demo-weblink-preview")
data = json.loads((root / "weblink-preview.json").read_text())
assert data.get("indexInsideVault") is False, "index must not live in vault"
assert data.get("cacheInsideVault") is False, "preview cache must not live in vault"
assert data.get("dailyUnchanged") is True, data
assert data.get("yamlContainsOgTitle") is False, data
assert data.get("previewTitle") == "Example Article", data.get("previewTitle")
assert data.get("previewDescription") == "A clipped paragraph from the page.", data
assert data.get("weblinkURL") == "https://example.com/article", data.get("weblinkURL")
assert (data.get("weblinkPath") or "").startswith("objects/weblink/"), data.get("weblinkPath")
cache = data.get("cachePath") or ""
vault = data.get("vaultRoot") or ""
assert cache, "cachePath missing"
assert vault, "vaultRoot missing"
assert not cache.startswith(vault), (cache, vault)
assert "previews.json" in cache, cache
assert data.get("fetchCountAfterOpen") == 1, data.get("fetchCountAfterOpen")
assert data.get("fetchCountAfterTypingSave") == 1, data.get("fetchCountAfterTypingSave")
proof = data.get("proof") or {}
assert proof.get("parsesOpenGraph") is True, proof
assert proof.get("cacheOutsideVault") is True, proof
assert proof.get("noFetchOnType") is True, proof
assert proof.get("indexInsideVault") is False, proof
print(
    "parsesOpenGraph cacheOutsideVault noFetchOnType "
    "dailyUnchanged cacheInsideVault=false indexInsideVault=false"
)
PY

echo "==> wrote $OUT_DIR/weblink-preview.json"
echo "==> demo-weblink-preview complete"

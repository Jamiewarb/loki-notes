#!/usr/bin/env bash
# scripts/demo-unlinked-mentions.sh — unlinked title mention proofs (PR44).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

export PATH="/opt/swift/usr/bin:${PATH:-}"

if ! command -v swift >/dev/null 2>&1; then
  echo "error: swift not found on PATH. Install toolchain (see AGENTS.md)." >&2
  exit 1
fi

OUT_DIR="$ROOT/DevHarness/public/demo-unlinked-mentions"
mkdir -p "$OUT_DIR"

echo "==> loci-unlinked-mentions-demo"
swift run --package-path "$ROOT" loci-unlinked-mentions-demo > "$OUT_DIR/unlinked-mentions.json"

python3 - <<'PY'
import json, pathlib

root = pathlib.Path("DevHarness/public/demo-unlinked-mentions")
data = json.loads((root / "unlinked-mentions.json").read_text())
assert data.get("indexInsideVault") is False, "index must not live in vault"
assert data.get("dailyUnchanged") is True, data
assert data.get("notesBodyContainsWikiLink") is False, data
assert (data.get("target") or {}).get("title") == "Deep Work", data.get("target")
assert (data.get("notes") or {}).get("title") == "Notes", data.get("notes")
body = (data.get("notes") or {}).get("bodyMarkdown") or ""
assert "Deep Work" in body, body
assert "[[" not in body, body
titles = data.get("mentionTitles") or []
assert "Notes" in titles, titles
assert "Journal" not in titles, titles
assert data.get("notesBodyAfterLinkContainsWikiLink") is True, data
after = data.get("notesBodyAfterLink") or ""
assert "[[" in after, after
assert (data.get("mentionsAfterLink") or []) == [], data.get("mentionsAfterLink")
proof = data.get("proof") or {}
assert proof.get("detectsPlainTitle") is True, proof
assert proof.get("ignoresExistingWikiLink") is True, proof
assert proof.get("doesNotRewriteBody") is True, proof
assert proof.get("indexInsideVault") is False, proof
print(
    "detectsPlainTitle ignoresExistingWikiLink doesNotRewriteBody "
    "dailyUnchanged notes has no [[ until Link indexInsideVault=false"
)
PY

echo "==> wrote $OUT_DIR/unlinked-mentions.json"
echo "==> demo-unlinked-mentions complete"

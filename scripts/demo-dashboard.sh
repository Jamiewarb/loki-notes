#!/usr/bin/env bash
# scripts/demo-dashboard.sh — type dashboard filter / sort / group proofs (PR41).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

export PATH="/opt/swift/usr/bin:${PATH:-}"

if ! command -v swift >/dev/null 2>&1; then
  echo "error: swift not found on PATH. Install toolchain (see AGENTS.md)." >&2
  exit 1
fi

OUT_DIR="$ROOT/DevHarness/public/demo-dashboard"
mkdir -p "$OUT_DIR"

echo "==> loci-dashboard-demo"
swift run --package-path "$ROOT" loci-dashboard-demo > "$OUT_DIR/dashboard.json"

python3 - <<'PY'
import json, pathlib

root = pathlib.Path("DevHarness/public/demo-dashboard")
data = json.loads((root / "dashboard.json").read_text())
assert data.get("indexInsideVault") is False, "index must not live in vault"
assert data.get("dailyUnchanged") is True, data
assert data.get("objectMarkdownUnchanged") is True, data
assert data.get("typeSchemaChanged") is True, data
proof = data.get("proof") or {}
assert proof.get("filterApplied") is True, proof
assert proof.get("sortApplied") is True, proof
assert proof.get("groupApplied") is True, proof
assert proof.get("resultsNotWrittenToMarkdown") is True, proof
assert proof.get("indexInsideVault") is False, proof
assert data.get("filteredTitles") == ["Deep Work", "Range"], data.get("filteredTitles")
sections = data.get("sections") or []
keys = [s.get("key") for s in sections]
assert "Reading" in keys, keys
dash = data.get("dashboard") or {}
assert dash.get("defaultSort") == "titleAsc", dash
assert dash.get("defaultGroupBy") == "status", dash
assert dash.get("defaultFilterKey") == "status", dash
assert dash.get("defaultFilterText") == "Reading", dash
snippet = data.get("typeSchemaSnippet") or ""
assert "defaultGroupBy" in snippet, snippet
assert "Deep Work" not in snippet
unfiltered = data.get("unfilteredSectionKeys") or []
assert "Reading" in unfiltered, unfiltered
print(
    "filterApplied sortApplied groupApplied resultsNotWrittenToMarkdown "
    "dailyUnchanged objectMarkdownUnchanged indexInsideVault=false"
)
PY

echo "==> wrote $OUT_DIR/dashboard.json"
echo "==> demo-dashboard complete"

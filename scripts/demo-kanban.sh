#!/usr/bin/env bash
# scripts/demo-kanban.sh — type dashboard Board / kanban proofs (PR42).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

export PATH="/opt/swift/usr/bin:${PATH:-}"

if ! command -v swift >/dev/null 2>&1; then
  echo "error: swift not found on PATH. Install toolchain (see AGENTS.md)." >&2
  exit 1
fi

OUT_DIR="$ROOT/DevHarness/public/demo-kanban"
mkdir -p "$OUT_DIR"

echo "==> loci-kanban-demo"
swift run --package-path "$ROOT" loci-kanban-demo > "$OUT_DIR/kanban.json"

python3 - <<'PY'
import json, pathlib

root = pathlib.Path("DevHarness/public/demo-kanban")
data = json.loads((root / "kanban.json").read_text())
assert data.get("indexInsideVault") is False, "index must not live in vault"
assert data.get("dailyUnchanged") is True, data
assert data.get("objectMarkdownUnchanged") is True, data
assert data.get("yamlStatusDone") is True, data
assert data.get("movedTitle") == "Deep Work", data.get("movedTitle")
assert data.get("movedFrom") == "Reading", data
assert data.get("movedTo") == "Done", data
assert data.get("typeSchemaChanged") is True, data
proof = data.get("proof") or {}
assert proof.get("boardColumnsFromGroup") is True, proof
assert proof.get("moveUpdatesVaultYAML") is True, proof
assert proof.get("layoutNotWrittenToMarkdown") is True, proof
assert proof.get("indexInsideVault") is False, proof
columns = data.get("columns") or []
keys = [c.get("key") for c in columns]
assert keys == ["To Read", "Reading", "Done"], keys
by_key = {c.get("key"): c.get("titles") or [] for c in columns}
assert "Deep Work" in by_key.get("Done", []), by_key
assert "Deep Work" not in by_key.get("Reading", []), by_key
assert "Range" in by_key.get("Reading", []), by_key
yaml = data.get("yamlSnippet") or ""
assert "Done" in yaml, yaml
assert "kanban-column" not in (data.get("books") or [{}])[0].get("bodyMarkdown", "")
dash = data.get("dashboard") or {}
assert dash.get("defaultView") == "board", dash
assert dash.get("defaultGroupBy") == "status", dash
snippet = data.get("typeSchemaSnippet") or ""
assert "defaultView" in snippet, snippet
assert "board" in snippet
print(
    "boardColumnsFromGroup moveUpdatesVaultYAML layoutNotWrittenToMarkdown "
    "dailyUnchanged yamlStatusDone indexInsideVault=false"
)
PY

echo "==> wrote $OUT_DIR/kanban.json"
echo "==> demo-kanban complete"

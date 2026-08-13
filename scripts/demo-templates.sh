#!/usr/bin/env bash
# scripts/demo-templates.sh — Book + Daily template fixtures for DevHarness (PR14).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

export PATH="/opt/swift/usr/bin:${PATH:-}"

if ! command -v swift >/dev/null 2>&1; then
  echo "error: swift not found on PATH. Install toolchain (see AGENTS.md)." >&2
  exit 1
fi

OUT_DIR="$ROOT/DevHarness/public/demo-templates"
mkdir -p "$OUT_DIR"

echo "==> loci-templates-demo"
swift run --package-path "$ROOT" loci-templates-demo > "$OUT_DIR/templates.json"

python3 - <<'PY'
import json, pathlib
root = pathlib.Path("DevHarness/public/demo-templates")
data = json.loads((root / "templates.json").read_text())
assert data.get("bookPrefill") is True, "Book default template must prefill headings + props"
assert data.get("dailyPrefill") is True, "Daily must use daily template"
assert data.get("indexInsideVault") is False, "index must not live in vault"
book_tpl = data.get("bookTemplate") or {}
assert book_tpl.get("id") == "book.default", book_tpl
assert book_tpl.get("exists") is True, book_tpl
daily_tpl = data.get("dailyTemplate") or {}
assert daily_tpl.get("id") == "daily.default", daily_tpl
assert daily_tpl.get("exists") is True, daily_tpl
book_obj = data.get("bookObject") or {}
body = book_obj.get("bodyMarkdown") or ""
assert "## Summary" in body and "## Quotes" in body, body
props = book_obj.get("properties") or {}
assert props.get("status") == "To Read", props
daily_obj = data.get("dailyObject") or {}
dbody = daily_obj.get("bodyMarkdown") or ""
assert "## Morning" in dbody and "## Evening" in dbody, dbody
book_type = data.get("bookType") or {}
assert book_type.get("defaultTemplateID") == "book.default", book_type
print(
    f"bookPrefill={data.get('bookPrefill')} dailyPrefill={data.get('dailyPrefill')} "
    f"bookTpl={book_tpl.get('id')} dailyTpl={daily_tpl.get('id')}"
)
PY

# Refresh Types panel fixtures with template proof.
TYPES_DIR="$ROOT/DevHarness/public/demo-types"
mkdir -p "$TYPES_DIR"
python3 - <<'PY'
import json, pathlib
tpl = json.loads(pathlib.Path("DevHarness/public/demo-templates/templates.json").read_text())
book = tpl.get("bookType") or {}
obj = tpl.get("bookObject") or {}
out = {
    "moduleVersion": tpl.get("moduleVersion"),
    "space": {"name": "Demo Templates", "schemaVersion": 1, "pins": []},
    "types": [
        {
            "id": "book",
            "name": book.get("name", "Books"),
            "icon": "book",
            "color": "#8B5A2B",
            "isBuiltIn": False,
            "properties": book.get("properties") or [],
            "defaultTemplateID": book.get("defaultTemplateID"),
            "templateIDs": book.get("templateIDs") or [],
        },
        {
            "id": "daily",
            "name": "Daily",
            "icon": "sun.max",
            "color": "#3D6B5C",
            "isBuiltIn": True,
            "properties": [],
            "defaultTemplateID": (tpl.get("dailyType") or {}).get("defaultTemplateID"),
            "templateIDs": (tpl.get("dailyType") or {}).get("templateIDs") or [],
        },
        {
            "id": "page",
            "name": "Page",
            "icon": "doc.text",
            "color": "#0F6B5C",
            "isBuiltIn": True,
            "properties": [],
        },
    ],
    "bookObject": {
        "id": obj.get("id"),
        "type": "book",
        "title": obj.get("title"),
        "relativePath": obj.get("relativePath"),
        "properties": obj.get("properties") or {},
        "bodyMarkdown": obj.get("bodyMarkdown"),
        "prefilledHeadings": obj.get("prefilledHeadings"),
    },
    "dailyObject": tpl.get("dailyObject"),
    "bookTemplate": tpl.get("bookTemplate"),
    "dailyTemplate": tpl.get("dailyTemplate"),
    "bookPrefill": tpl.get("bookPrefill"),
    "dailyPrefill": tpl.get("dailyPrefill"),
    "booksCount": 1,
    "pagesCount": 0,
    "appearsOnlyUnderBooks": True,
    "objectsFolder": "objects/book",
    "objectsFolderExists": True,
    "pageDeleteBlocked": True,
    "survivedReload": True,
    "frontmatterSnippet": tpl.get("frontmatterSnippet"),
    "note": tpl.get("note"),
}
pathlib.Path("DevHarness/public/demo-types/types.json").write_text(
    json.dumps(out, indent=2) + "\n"
)
print("wrote DevHarness/public/demo-types/types.json (with templates)")
PY

SCHEMA_DIR="$ROOT/DevHarness/public/demo-schema"
mkdir -p "$SCHEMA_DIR/types" "$SCHEMA_DIR/templates"
python3 - <<'PY'
import json, pathlib
tpl = json.loads(pathlib.Path("DevHarness/public/demo-templates/templates.json").read_text())
schema = pathlib.Path("DevHarness/public/demo-schema")
space = {"name": "Demo Templates", "schemaVersion": 1, "pins": []}
(schema / "space.json").write_text(json.dumps(space, indent=2) + "\n")
book = tpl.get("bookType") or {}
daily = tpl.get("dailyType") or {}
types = [
    {
        "id": "book",
        "name": book.get("name", "Books"),
        "icon": "book",
        "color": "#8B5A2B",
        "isBuiltIn": False,
        "properties": book.get("properties") or [],
        "defaultTemplateID": book.get("defaultTemplateID"),
        "templateIDs": book.get("templateIDs") or [],
    },
    {
        "id": "daily",
        "name": "Daily",
        "icon": "sun.max",
        "color": "#3D6B5C",
        "isBuiltIn": True,
        "properties": [],
        "defaultTemplateID": daily.get("defaultTemplateID"),
        "templateIDs": daily.get("templateIDs") or [],
    },
    {"id": "page", "name": "Page", "icon": "doc.text", "color": "#0F6B5C", "isBuiltIn": True, "properties": []},
]
types_dir = schema / "types"
for t in types:
    (types_dir / f"{t['id']}.json").write_text(json.dumps(t, indent=2) + "\n")

# Write template markdown fixtures for harness browsing.
book_tpl = tpl.get("bookTemplate") or {}
daily_tpl = tpl.get("dailyTemplate") or {}
templates_dir = schema / "templates"
book_md = f"""---
id: book.default
type: book
name: Default Book
properties:
  status:
    kind: select
    value: To Read
  rating:
    kind: number
    value: 0
---

{book_tpl.get('bodyPreview') or '## Summary'}
"""
daily_md = f"""---
id: daily.default
type: daily
name: Daily Default
---

{daily_tpl.get('bodyPreview') or '## Morning'}
"""
(templates_dir / "book.default.md").write_text(book_md)
(templates_dir / "daily.default.md").write_text(daily_md)

manifest = {
    "space": space,
    "types": types,
    "templates": {
        "book": book_tpl,
        "daily": daily_tpl,
    },
    "templatesDemo": {
        "bookObject": tpl.get("bookObject"),
        "dailyObject": tpl.get("dailyObject"),
        "bookPrefill": tpl.get("bookPrefill"),
        "dailyPrefill": tpl.get("dailyPrefill"),
    },
    "note": "Generated by scripts/demo-templates.sh — Book + Daily templates (PR14).",
}
(schema / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
print("wrote", schema / "manifest.json")
PY

echo "==> wrote $OUT_DIR/templates.json"
echo "==> demo-templates complete"

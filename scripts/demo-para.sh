#!/usr/bin/env bash
# scripts/demo-para.sh — PARA starter pack fixtures for DevHarness (PR15).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

export PATH="/opt/swift/usr/bin:${PATH:-}"

if ! command -v swift >/dev/null 2>&1; then
  echo "error: swift not found on PATH. Install toolchain (see AGENTS.md)." >&2
  exit 1
fi

OUT_DIR="$ROOT/DevHarness/public/demo-para"
mkdir -p "$OUT_DIR"

echo "==> loci-para-demo"
swift run --package-path "$ROOT" loci-para-demo > "$OUT_DIR/para.json"

python3 - <<'PY'
import json, pathlib
root = pathlib.Path("DevHarness/public/demo-para")
data = json.loads((root / "para.json").read_text())
assert data.get("idempotent") is True, "second apply must be idempotent"
assert data.get("resourceTypeExists") is False, "Resource must be tag approach, not a type"
space = data.get("space") or {}
assert space.get("paraPackApplied") is True, space
assert space.get("hideArchived") is True, space
assert space.get("resourceApproach") == "tag:#resource", space
assert space.get("archiveApproach") == "tag:#archive", space
project = data.get("projectType") or {}
assert project.get("id") == "project", project
assert project.get("defaultTemplateID") == "project.default", project
assert project.get("hideArchived") is True, project
area = data.get("areaType") or {}
assert area.get("id") == "area", area
assert area.get("defaultTemplateID") == "area.default", area
pt = data.get("projectTemplate") or {}
assert pt.get("id") == "project.default" and pt.get("exists") is True, pt
at = data.get("areaTemplate") or {}
assert at.get("id") == "area.default" and at.get("exists") is True, at
pobj = data.get("projectObject") or {}
assert pobj.get("prefilled") is True, pobj
body = pobj.get("bodyMarkdown") or ""
assert "## Outcome" in body and "## Next actions" in body, body
aobj = data.get("areaObject") or {}
assert aobj.get("prefilled") is True, aobj
filt = data.get("archiveFilter") or {}
assert filt.get("noFolderMove") is True, filt
assert filt.get("archivedHidden", 0) >= 1, filt
assert filt.get("visibleWhenHideArchived", 0) >= 1, filt
assert data.get("indexInsideVault") is False, "index must not live in vault"
print(
    f"paraPackApplied={space.get('paraPackApplied')} project={project.get('defaultTemplateID')} "
    f"area={area.get('defaultTemplateID')} archivedHidden={filt.get('archivedHidden')} "
    f"idempotent={data.get('idempotent')}"
)
PY

# Refresh Types panel fixtures with Project/Area.
TYPES_DIR="$ROOT/DevHarness/public/demo-types"
mkdir -p "$TYPES_DIR"
python3 - <<'PY'
import json, pathlib
para = json.loads(pathlib.Path("DevHarness/public/demo-para/para.json").read_text())
project = para.get("projectType") or {}
area = para.get("areaType") or {}
out = {
    "moduleVersion": para.get("moduleVersion"),
    "space": para.get("space") or {},
    "types": [
        {
            "id": "project",
            "name": project.get("name", "Project"),
            "icon": project.get("icon", "flag"),
            "color": project.get("color", "#B85C38"),
            "isBuiltIn": False,
            "properties": project.get("properties") or [],
            "defaultTemplateID": project.get("defaultTemplateID"),
            "templateIDs": project.get("templateIDs") or [],
            "hideArchived": project.get("hideArchived"),
        },
        {
            "id": "area",
            "name": area.get("name", "Area"),
            "icon": area.get("icon", "square.grid.2x2"),
            "color": area.get("color", "#2A6F97"),
            "isBuiltIn": False,
            "properties": area.get("properties") or [],
            "defaultTemplateID": area.get("defaultTemplateID"),
            "templateIDs": area.get("templateIDs") or [],
            "hideArchived": area.get("hideArchived"),
        },
        {
            "id": "daily",
            "name": "Daily",
            "icon": "sun.max",
            "color": "#3D6B5C",
            "isBuiltIn": True,
            "properties": [],
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
    "projectObject": para.get("projectObject"),
    "areaObject": para.get("areaObject"),
    "projectTemplate": para.get("projectTemplate"),
    "areaTemplate": para.get("areaTemplate"),
    "archiveFilter": para.get("archiveFilter"),
    "para": {
        "explainer": para.get("explainer"),
        "resourceGuidance": para.get("resourceGuidance"),
        "archiveGuidance": para.get("archiveGuidance"),
        "resourceApproach": (para.get("space") or {}).get("resourceApproach"),
        "archiveApproach": (para.get("space") or {}).get("archiveApproach"),
        "idempotent": para.get("idempotent"),
        "resourceTypeExists": para.get("resourceTypeExists"),
    },
    "note": para.get("note"),
}
pathlib.Path("DevHarness/public/demo-types/types.json").write_text(
    json.dumps(out, indent=2) + "\n"
)
print("wrote DevHarness/public/demo-types/types.json (with PARA)")
PY

SCHEMA_DIR="$ROOT/DevHarness/public/demo-schema"
mkdir -p "$SCHEMA_DIR/types" "$SCHEMA_DIR/templates"
python3 - <<'PY'
import json, pathlib
para = json.loads(pathlib.Path("DevHarness/public/demo-para/para.json").read_text())
schema = pathlib.Path("DevHarness/public/demo-schema")
space = para.get("space") or {"name": "Demo PARA", "schemaVersion": 1, "pins": []}
(schema / "space.json").write_text(json.dumps(space, indent=2) + "\n")
project = para.get("projectType") or {}
area = para.get("areaType") or {}
types = [
    {
        "id": "project",
        "name": project.get("name", "Project"),
        "icon": project.get("icon", "flag"),
        "color": project.get("color", "#B85C38"),
        "isBuiltIn": False,
        "properties": project.get("properties") or [],
        "defaultTemplateID": project.get("defaultTemplateID"),
        "templateIDs": project.get("templateIDs") or [],
        "dashboard": {"hideArchived": True, "cardPreviewPropertyIDs": ["status"], "defaultSort": "updated"},
    },
    {
        "id": "area",
        "name": area.get("name", "Area"),
        "icon": area.get("icon", "square.grid.2x2"),
        "color": area.get("color", "#2A6F97"),
        "isBuiltIn": False,
        "properties": area.get("properties") or [],
        "defaultTemplateID": area.get("defaultTemplateID"),
        "templateIDs": area.get("templateIDs") or [],
        "dashboard": {"hideArchived": True, "cardPreviewPropertyIDs": ["status"], "defaultSort": "updated"},
    },
    {"id": "daily", "name": "Daily", "icon": "sun.max", "color": "#3D6B5C", "isBuiltIn": True, "properties": []},
    {"id": "page", "name": "Page", "icon": "doc.text", "color": "#0F6B5C", "isBuiltIn": True, "properties": []},
]
types_dir = schema / "types"
for t in types:
    (types_dir / f"{t['id']}.json").write_text(json.dumps(t, indent=2) + "\n")

pt = para.get("projectTemplate") or {}
at = para.get("areaTemplate") or {}
templates_dir = schema / "templates"
(templates_dir / "project.default.md").write_text(
    f"""---
id: project.default
type: project
name: Default Project
properties:
  status:
    kind: select
    value: Active
---

{pt.get('bodyPreview') or '## Outcome'}
"""
)
(templates_dir / "area.default.md").write_text(
    f"""---
id: area.default
type: area
name: Default Area
properties:
  status:
    kind: select
    value: Active
  review:
    kind: select
    value: Monthly
---

{at.get('bodyPreview') or '## Standards'}
"""
)

manifest = {
    "space": space,
    "types": types,
    "templates": {"project": pt, "area": at},
    "para": {
        "explainer": para.get("explainer"),
        "resourceGuidance": para.get("resourceGuidance"),
        "archiveGuidance": para.get("archiveGuidance"),
        "archiveFilter": para.get("archiveFilter"),
        "idempotent": para.get("idempotent"),
    },
    "note": "Generated by scripts/demo-para.sh — PARA Project/Area pack (PR15).",
}
(schema / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
print("wrote", schema / "manifest.json")
PY

echo "==> wrote $OUT_DIR/para.json"
echo "==> demo-para complete"

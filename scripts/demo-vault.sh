#!/usr/bin/env bash
# scripts/demo-vault.sh — create a temp local vault via loci-vault-demo (PR04).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

export PATH="/opt/swift/usr/bin:${PATH:-}"

if ! command -v swift >/dev/null 2>&1; then
  echo "error: swift not found on PATH. Install toolchain (see AGENTS.md)." >&2
  exit 1
fi

DEMO_PARENT="${LOCI_VAULT_PARENT:-}"
if [[ -z "$DEMO_PARENT" ]]; then
  DEMO_PARENT="$(mktemp -d /tmp/loci-vault-demo.XXXXXX)"
fi
export LOCI_VAULT_PARENT="$DEMO_PARENT"

echo "==> loci-vault-demo (parent: $LOCI_VAULT_PARENT)"
swift run --package-path "$ROOT" loci-vault-demo
echo "==> demo complete"

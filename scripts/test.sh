#!/usr/bin/env bash
# scripts/test.sh — run Linux-buildable Swift package tests.
# Exits non-zero on failure. Used by Cloud agents and CI.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

export PATH="/opt/swift/usr/bin:${PATH:-}"

if ! command -v swift >/dev/null 2>&1; then
  echo "error: swift not found on PATH. Install toolchain (see AGENTS.md)." >&2
  exit 1
fi

echo "==> swift --version"
swift --version

echo "==> swift test"
swift test --package-path "$ROOT"

echo "==> tests passed"

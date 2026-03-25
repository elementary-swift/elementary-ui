#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$SCRIPT_DIR/.."
GENERATED_SWIFT_FILE="$ROOT_DIR/Sources/BrowserInterop/Generated/BridgeJS.swift"

cd "$ROOT_DIR"

echo "Generating BridgeJS artifacts for BrowserInterop..."
swift package --allow-writing-to-package-directory bridge-js --target BrowserInterop

if [[ -f "$GENERATED_SWIFT_FILE" ]]; then
  if ! rg -q '^// swift-format-ignore-file$' "$GENERATED_SWIFT_FILE"; then
    tmp_file="$(mktemp)"
    {
      echo "// swift-format-ignore-file"
      echo
      cat "$GENERATED_SWIFT_FILE"
    } > "$tmp_file"
    mv "$tmp_file" "$GENERATED_SWIFT_FILE"
  fi
fi

echo "BridgeJS generation complete."
echo "If you need BrowserRuntime runtime wiring, run Scripts/fold-bridgejs-runtime.sh"

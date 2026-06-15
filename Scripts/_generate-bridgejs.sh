#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$SCRIPT_DIR/.."
GENERATED_SWIFT_FILE="$ROOT_DIR/Sources/BrowserInterop/Generated/BridgeJS.swift"

cd "$ROOT_DIR"

echo "Generating BridgeJS artifacts for BrowserInterop..."
swift package --build-system swiftbuild --allow-writing-to-package-directory bridge-js --target BrowserInterop

echo "BridgeJS generation complete."

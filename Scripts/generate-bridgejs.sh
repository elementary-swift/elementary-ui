#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$SCRIPT_DIR/.."

cd "$ROOT_DIR"

echo "Generating BridgeJS artifacts for BrowserInterop..."
swift package --explicit-target-dependency-import-check=error --disable-experimental-prebuilts --allow-writing-to-package-directory bridge-js --target BrowserInterop

echo "BridgeJS generation complete."
echo "If you need BrowserRuntime runtime wiring, run Scripts/fold-bridgejs-runtime.sh"

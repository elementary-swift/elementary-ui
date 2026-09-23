#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$SCRIPT_DIR/.."
cd "$ROOT_DIR"

for target in BrowserInterop ElementaryWebComponents; do
  echo "Generating BridgeJS artifacts for $target..."
  swift package --build-system swiftbuild --allow-writing-to-package-directory bridge-js --target "$target"
done

echo "BridgeJS generation complete."

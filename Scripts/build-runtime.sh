#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

"$SCRIPT_DIR/_generate-bridgejs.sh"

# Build the JavaScriptKit runtime (uses typescript rolldown, goshdarn const enums....)
JSKITDIR="$SCRIPT_DIR/../.build/checkouts/JavaScriptKit"
VENDORDIR="$SCRIPT_DIR/../BrowserRuntime/src/vendored/javascriptkit"

cd "$JSKITDIR"
npm ci
npm run build

rm -rf "$VENDORDIR"/*
cp Runtime/lib/* "$VENDORDIR/"
cp LICENSE "$VENDORDIR/"

cd "$SCRIPT_DIR/../BrowserRuntime"
"$SCRIPT_DIR/_fold-bridgejs-runtime.sh"
pnpm install
pnpm build

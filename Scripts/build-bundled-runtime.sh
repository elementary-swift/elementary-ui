#!/bin/bash
set -euo pipefail

# Build the JavaScriptKit runtime (uses typescript rolldown, goshdarn const enums....)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
JSKITDIR="$SCRIPT_DIR/../.build/checkouts/JavaScriptKit"
VENDORDIR="$SCRIPT_DIR/../BrowserRuntime/src/vendored/javascriptkit"

cd "$JSKITDIR"
pnpm install --frozen-lockfile
pnpm run build

rm -rf "$VENDORDIR"/*
cp Runtime/lib/* "$VENDORDIR/"
cp LICENSE "$VENDORDIR/"

########################################################
# Build the BrowserRuntime
########################################################

cd "$SCRIPT_DIR/../BrowserRuntime"
# Fold generated BridgeJS runtime artifacts unless explicitly skipped.
if [[ "${SKIP_BRIDGEJS_FOLD:-0}" != "1" ]]; then
  "$SCRIPT_DIR/fold-bridgejs-runtime.sh"
fi
pnpm install
pnpm build
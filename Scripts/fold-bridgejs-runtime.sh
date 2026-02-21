#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$SCRIPT_DIR/.."
RUNTIME_DIR="$ROOT_DIR/BrowserRuntime/src/generated"
SKELETON_JSON="$ROOT_DIR/Sources/BrowserInterop/Generated/JavaScript/BridgeJS.json"

mkdir -p "$RUNTIME_DIR"

SOURCE_JS="${1:-${BRIDGE_JS_SOURCE:-}}"

if [[ -z "$SOURCE_JS" ]]; then
  CANDIDATES=(
    "$ROOT_DIR/.build/plugins/PackageToJS/outputs/Package/bridge-js.js"
    "$ROOT_DIR/.build/plugins/PackageToJS/outputs/elementary-ui/bridge-js.js"
    "$ROOT_DIR/Benchmarks/PerformanceBenchmarks/.build/plugins/PackageToJS/outputs/Package/bridge-js.js"
    "$ROOT_DIR/Benchmarks/PerformanceBenchmarks/.build/index-build/plugins/PackageToJS/outputs/Package/bridge-js.js"
  )
  for candidate in "${CANDIDATES[@]}"; do
    if [[ -f "$candidate" ]]; then
      SOURCE_JS="$candidate"
      break
    fi
  done
fi

if [[ -z "$SOURCE_JS" && -f "$SKELETON_JSON" ]]; then
  TMP_JS="$ROOT_DIR/.build/bridge-js.js"
  TMP_DTS="$ROOT_DIR/.build/bridge-js.d.ts"
  BRIDGEJS_TOOL_PATH="$ROOT_DIR/.build/checkouts/JavaScriptKit/Plugins/BridgeJS"

  echo "No bridge-js.js provided; generating from BrowserInterop skeleton..."
  swift run --package-path "$BRIDGEJS_TOOL_PATH" BridgeJSToolInternal emit-js "$SKELETON_JSON" > "$TMP_JS"
  swift run --package-path "$BRIDGEJS_TOOL_PATH" BridgeJSToolInternal emit-dts "$SKELETON_JSON" > "$TMP_DTS"
  SOURCE_JS="$TMP_JS"
fi

if [[ -z "$SOURCE_JS" || ! -f "$SOURCE_JS" ]]; then
  echo "Could not find or generate bridge-js.js."
  echo "Pass the source path explicitly:"
  echo "  Scripts/fold-bridgejs-runtime.sh /path/to/bridge-js.js"
  echo "Or ensure BrowserInterop BridgeJS skeleton exists at:"
  echo "  $SKELETON_JSON"
  exit 1
fi

SOURCE_DTS="${SOURCE_JS%.js}.d.ts"

cp "$SOURCE_JS" "$RUNTIME_DIR/bridge-js.js"
if [[ -f "$SOURCE_DTS" ]]; then
  cp "$SOURCE_DTS" "$RUNTIME_DIR/bridge-js.d.ts"
fi

echo "Folded BridgeJS runtime artifacts into BrowserRuntime:"
echo "  $RUNTIME_DIR/bridge-js.js"
if [[ -f "$SOURCE_DTS" ]]; then
  echo "  $RUNTIME_DIR/bridge-js.d.ts"
fi

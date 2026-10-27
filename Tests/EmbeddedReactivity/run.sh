#!/bin/sh
set -eu
reactivity_repo=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
reactivity_smoke=$(mktemp -d "${TMPDIR:-/tmp}/reactivity-smoke.XXXXXX")
trap 'rm -rf "$reactivity_smoke"' EXIT
mkdir -p "$reactivity_smoke/Sources/Smoke"
cp "$reactivity_repo/Tests/EmbeddedReactivity/Package.swift" "$reactivity_smoke/Package.swift"
cp "$reactivity_repo/Tests/EmbeddedReactivity/main.swift" "$reactivity_smoke/Sources/Smoke/main.swift"
for reactivity_target in Reactivity ReactivityMacros _UTF8Internals; do
    cp -R "$reactivity_repo/Sources/$reactivity_target" "$reactivity_smoke/Sources/$reactivity_target"
done
"${REACTIVITY_SWIFT:-swift}" build --build-system native --package-path "$reactivity_smoke" --swift-sdk "${REACTIVITY_SWIFT_SDK:-swift-6.4.0-RELEASE_wasm-embedded}" -c release
"${REACTIVITY_WASMKIT:-wasmkit}" run "$reactivity_smoke/.build/wasm32-unknown-wasip1/release/Smoke.wasm"

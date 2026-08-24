# ElementaryUI Browser Runtime

Bundled JavaScriptKit + WASI bootstrap for running ElementaryUI WebAssembly applications in the browser.

> [!WARNING]
> This bundled runtime is deprecated. Use the [`?js` mode introduced in
> vite-plugin-swift-wasm 0.2](https://github.com/elementary-swift/vite-plugin-swift-wasm/releases/tag/v0.2.0)
> instead. It uses JavaScriptKit's `swift package js` command and supports
> [BridgeJS](https://swiftpackageindex.com/swiftwasm/javascriptkit/documentation/javascriptkit/introducing-bridgejs).

## What is this?

This package provides JavaScript glue code to run ElementaryUI WebAssembly applications in the browser.

- **JavaScriptKit Runtime** - Swift-to-JavaScript interop layer (vendored from [JavaScriptKit](https://github.com/swiftwasm/JavaScriptKit))
- **WASI Bootstrap** - Minimal WASI setup for browser environments ([@bjorn3/browser_wasi_shim](https://github.com/bjorn3/browser_wasi_shim))

## Deprecated usage
```ts
import { runApplication } from "elementary-ui-browser-runtime";

await runApplication(async (imports) => {
  const { instance } = await WebAssembly.instantiateStreaming(
    fetch("./App.wasm"),
    imports
  );
  return instance;
});
```

## License

This package contains code under multiple licenses. See [LICENSE](LICENSE.md) for details.
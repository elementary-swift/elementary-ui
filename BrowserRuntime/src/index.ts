import { createDefaultWASI } from "./wasi-shim";
import { SwiftRuntime } from "./vendored/javascriptkit/index.mjs";
import { createInstantiator } from "./generated/bridge-js";

type WasmInstanceInitializer = (
  importsObject?: WebAssembly.Imports
) => Promise<WebAssembly.Instance>;

// TODO: offer more customization entry-points (ie: BYO WASI, BYO JavaScriptKit SwiftRuntime, figure out BridgeJS inclusion, ...)

/**
 * Runs an ElementaryUI application.
 *
 * This function bootstraps a JavaScriptKit SwiftRuntime and WASI shim,
 * then runs the application by calling Swift's main entry point.
 *
 * @param initializer - A function that receives WebAssembly imports and returns a WebAssembly instance.
 * @returns A promise that resolves when initialization is complete and the Swift application has started.
 */
export async function runApplication(initializer: WasmInstanceInitializer) {
  const wasi = createDefaultWASI();
  const swiftRuntime = new SwiftRuntime();
  let instance: WebAssembly.Instance | null = null;
  const instantiator = await createInstantiator({
    imports: {},
  }, swiftRuntime as any);
  const importsObject: WebAssembly.Imports = {
    javascript_kit: swiftRuntime.wasmImports,
    wasi_snapshot_preview1: wasi.wasiImport,
  };
  instantiator.addImports(importsObject);

  instance = await initializer(importsObject);

  swiftRuntime.setInstance(instance);
  instantiator.setInstance(instance);
  // TODO: deal with this typing issue later
  wasi.initialize(instance as any);

  swiftRuntime.main();
}

//#region src/index.d.ts
type WasmInstanceInitializer = (importsObject?: WebAssembly.Imports) => Promise<WebAssembly.Instance>;
/**
 * Runs an ElementaryUI application.
 *
 * This function bootstraps a JavaScriptKit SwiftRuntime and WASI shim,
 * then runs the application by calling Swift's main entry point.
 *
 * @param initializer - A function that receives WebAssembly imports and returns a WebAssembly instance.
 * @returns A promise that resolves when initialization is complete and the Swift application has started.
 */
declare function runApplication(initializer: WasmInstanceInitializer): Promise<void>;
//#endregion
export { runApplication };
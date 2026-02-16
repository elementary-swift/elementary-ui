import { defineConfig, Plugin } from "vite";
import swiftWasm from "@elementary-swift/vite-plugin-swift-wasm";

const product = process.env.BENCH_PRODUCT;
if (!product) {
  throw new Error(
    "BENCH_PRODUCT environment variable is required. Set it to the target name (e.g. HelloWorld).",
  );
}

// Replaces the BENCH_PRODUCT placeholder in the import specifier with the
// actual product name from the environment variable.
function injectBenchProduct(): Plugin {
  return {
    name: "inject-bench-product",
    enforce: "pre",
    resolveId(id, importer, options) {
      if (id === "virtual:swift-wasm?init&product=$PRODUCT") {
        return this.resolve(
          `virtual:swift-wasm?init&product=${product}`,
          importer,
          { ...options, skipSelf: true },
        );
      }
    },
  };
}

export default defineConfig({
  build: {
    outDir: `dist/${product}`,
  },
  plugins: [
    injectBenchProduct(),
    swiftWasm({
      useEmbeddedSDK: true,
      linkEmbeddedUnicodeDataTables: false
    })],
});

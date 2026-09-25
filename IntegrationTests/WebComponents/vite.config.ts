import { defineConfig } from "vite";
import swiftWasm from "@elementary-swift/vite-plugin-swift-wasm";

export default defineConfig({
  plugins: [
    swiftWasm({
      useEmbeddedSDK: true,
    }),
    {
      name: "elementary-hmr-test-hook",
      enforce: "pre",
      transform(code) {
        if (!code.includes("import.meta.hot")) return;
        // Keep the HMR branch in the preview bundle so tests can trigger it
        // without a second Swift dev-server build.
        return code.replaceAll(
          "import.meta.hot",
          "(import.meta.hot||globalThis.__elementaryHotReload)"
        );
      },
    },
  ],
});

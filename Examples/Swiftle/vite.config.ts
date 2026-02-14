import { defineConfig } from "vite";
import swiftWasm from "@elementary-swift/vite-plugin-swift-wasm";
import { resolve } from "node:path";

export default defineConfig({
  resolve: {
    alias: {
      "ElementaryFlow": resolve(__dirname, ".build/checkouts/elementary-flow/css/elementary-flow.css"),
    },
  },
  plugins: [
    swiftWasm({
      useEmbeddedSDK: true,
      linkEmbeddedUnicodeDataTables: false
    })]
});
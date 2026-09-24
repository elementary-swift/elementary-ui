import { defineConfig } from "@playwright/test";

export default defineConfig({
  testDir: "./Tests",
  timeout: 30_000,
  use: {
    headless: true,
  },
  webServer: {
    command: "pnpm preview",
    port: 4174,
    reuseExistingServer: !process.env.CI,
    timeout: 120_000,
  },
});

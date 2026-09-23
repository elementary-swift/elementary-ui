import { defineConfig } from "@playwright/test";

export default defineConfig({
  testDir: "./Tests",
  timeout: 60_000,
  use: {
    headless: true,
  },
  webServer: [
    {
      command: "pnpm dev",
      port: 4173,
      reuseExistingServer: !process.env.CI,
      timeout: 120_000,
    },
    {
      command: "pnpm preview",
      port: 4174,
      reuseExistingServer: !process.env.CI,
      timeout: 120_000,
    },
  ],
});

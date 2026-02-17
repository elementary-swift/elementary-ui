#!/usr/bin/env node

// Builds the benchmark app via `vite build`, serves it with `vite preview`,
// then uses Playwright (headless Chromium) to run js-framework-benchmark-style
// operations and measure timing + memory via Chrome DevTools Protocol.
//
// Benchmark parameters (warmup counts, CPU throttling, naming) match the
// official js-framework-benchmark configuration:
// https://github.com/krausest/js-framework-benchmark/blob/master/webdriver-ts/src/benchmarksCommon.ts
//
// Outputs JSON in github-action-benchmark's "customSmallerIsBetter" format.
//
// Usage: node scripts/measure-perf.mjs
//        node scripts/measure-perf.mjs --iterations 5

import { spawn, spawnSync } from "node:child_process";
import { resolve, dirname } from "node:path";
import { fileURLToPath } from "node:url";
import { chromium } from "playwright";

const __dirname = dirname(fileURLToPath(import.meta.url));
const projectRoot = resolve(__dirname, "..");

const ITERATIONS = parseInt(
  process.argv.find((_, i, a) => a[i - 1] === "--iterations") ?? "10",
  10,
);
const PREVIEW_PORT = 4173;
const PREVIEW_URL = `http://localhost:${PREVIEW_PORT}`;

// ---------------------------------------------------------------------------
// Build
// ---------------------------------------------------------------------------

function build() {
  console.error("Building benchmark app...");
  const result = spawnSync(
    resolve(projectRoot, "node_modules/.bin/vite"),
    ["build"],
    {
      cwd: projectRoot,
      encoding: "utf-8",
      timeout: 600_000,
      stdio: ["ignore", "pipe", "pipe"],
    },
  );
  if (result.status !== 0) {
    throw new Error(
      `vite build failed:\n${result.stdout}\n${result.stderr}`,
    );
  }
  console.error("Build complete.");
}

// ---------------------------------------------------------------------------
// Preview server
// ---------------------------------------------------------------------------

function startPreview() {
  return new Promise((resolve, reject) => {
    const proc = spawn(
      "node_modules/.bin/vite",
      ["preview", "--port", String(PREVIEW_PORT), "--strictPort"],
      {
        cwd: projectRoot,
        stdio: ["ignore", "pipe", "pipe"],
      },
    );

    let settled = false;
    const timeout = setTimeout(() => {
      if (!settled) {
        settled = true;
        reject(new Error("Preview server did not start within 15s"));
      }
    }, 15_000);

    const onData = (chunk) => {
      if (!settled && chunk.toString().includes("Local:")) {
        settled = true;
        clearTimeout(timeout);
        resolve(proc);
      }
    };

    proc.stdout.on("data", onData);
    proc.stderr.on("data", onData);

    proc.on("error", (err) => {
      if (!settled) {
        settled = true;
        clearTimeout(timeout);
        reject(err);
      }
    });

    proc.on("exit", (code) => {
      if (!settled) {
        settled = true;
        clearTimeout(timeout);
        reject(new Error(`Preview server exited with code ${code}`));
      }
    });
  });
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

function median(values) {
  const sorted = [...values].sort((a, b) => a - b);
  const mid = Math.floor(sorted.length / 2);
  return sorted.length % 2 !== 0
    ? sorted[mid]
    : (sorted[mid - 1] + sorted[mid]) / 2;
}

async function waitForReady(page) {
  await page.waitForSelector("#app[data-ready='true']", { timeout: 30_000 });
}

async function waitForRowCount(page, expected) {
  await page.waitForFunction(
    (n) => document.querySelectorAll("#tbody tr").length === n,
    expected,
    { timeout: 30_000 },
  );
}

// ---------------------------------------------------------------------------
// CPU throttling via CDP
// ---------------------------------------------------------------------------

async function setCPUThrottling(cdp, factor) {
  if (factor && factor > 1) {
    await cdp.send("Emulation.setCPUThrottlingRate", { rate: factor });
  } else {
    await cdp.send("Emulation.setCPUThrottlingRate", { rate: 1 });
  }
}

// ---------------------------------------------------------------------------
// Timing measurement via performance.now()
//
// We measure from just before the click to after the DOM has settled and
// a requestAnimationFrame fires (indicating the browser has rendered).
// ---------------------------------------------------------------------------

async function measureClick(page, selector, waitConditionFn) {
  const duration = await page.evaluate(
    async ({ selector }) => {
      const el = document.querySelector(selector);
      if (!el) throw new Error(`Element not found: ${selector}`);

      const start = performance.now();
      el.click();

      // Wait for the next animation frame to ensure rendering
      await new Promise((r) => requestAnimationFrame(r));
      // Wait one more frame to ensure paint
      await new Promise((r) => requestAnimationFrame(r));

      return performance.now() - start;
    },
    { selector },
  );

  // Optionally wait for a DOM condition from the Playwright side (more robust)
  if (waitConditionFn) {
    await waitConditionFn(page);
  }

  return duration;
}

// ---------------------------------------------------------------------------
// Timing benchmarks
// Matches js-framework-benchmark official configuration:
// https://github.com/krausest/js-framework-benchmark/blob/master/webdriver-ts/src/benchmarksCommon.ts
// ---------------------------------------------------------------------------

const timingBenchmarks = [
  {
    id: "01_run1k",
    label: "create rows",
    warmup: 5,
    cpuThrottle: undefined,
    setup: null,
    action: "#run",
    wait: (page) => waitForRowCount(page, 1000),
  },
  {
    id: "02_replace1k",
    label: "replace all rows",
    warmup: 5,
    cpuThrottle: undefined,
    setup: async (page) => {
      await page.click("#run");
      await waitForRowCount(page, 1000);
    },
    action: "#run",
    wait: (page) => waitForRowCount(page, 1000),
  },
  {
    id: "03_update10th1k_x16",
    label: "partial update",
    warmup: 3,
    cpuThrottle: 4,
    setup: async (page) => {
      await page.click("#run");
      await waitForRowCount(page, 1000);
    },
    action: "#update",
    wait: null,
  },
  {
    id: "04_select1k",
    label: "select row",
    warmup: 5,
    cpuThrottle: 4,
    setup: async (page) => {
      await page.click("#run");
      await waitForRowCount(page, 1000);
    },
    action: "#tbody tr:nth-child(2) td:nth-child(2) a",
    wait: (page) =>
      page.waitForFunction(
        () => {
          const row = document.querySelector("#tbody tr:nth-child(2)");
          return row && row.classList.contains("danger");
        },
        { timeout: 10_000 },
      ),
  },
  {
    id: "05_swap1k",
    label: "swap rows",
    warmup: 5,
    cpuThrottle: 4,
    setup: async (page) => {
      await page.click("#run");
      await waitForRowCount(page, 1000);
    },
    action: "#swaprows",
    wait: null,
  },
  {
    id: "06_remove-one-1k",
    label: "remove row",
    warmup: 5,
    cpuThrottle: 2,
    setup: async (page) => {
      await page.click("#run");
      await waitForRowCount(page, 1000);
    },
    action: "#tbody tr:nth-child(2) td:nth-child(3) a",
    wait: (page) => waitForRowCount(page, 999),
  },
  {
    id: "07_create10k",
    label: "create many rows",
    warmup: 5,
    cpuThrottle: undefined,
    setup: null,
    action: "#runlots",
    wait: (page) => waitForRowCount(page, 10000),
  },
  {
    id: "08_create1k-after1k_x2",
    label: "append rows to large table",
    warmup: 5,
    cpuThrottle: undefined,
    setup: async (page) => {
      await page.click("#run");
      await waitForRowCount(page, 1000);
    },
    action: "#add",
    wait: (page) => waitForRowCount(page, 2000),
  },
  {
    id: "09_clear1k_x8",
    label: "clear rows",
    warmup: 5,
    cpuThrottle: 4,
    setup: async (page) => {
      await page.click("#run");
      await waitForRowCount(page, 1000);
    },
    action: "#clear",
    wait: (page) => waitForRowCount(page, 0),
  },
];

// ---------------------------------------------------------------------------
// Memory benchmarks (via CDP)
// Matches js-framework-benchmark: only the 3 active memory benchmarks.
// ---------------------------------------------------------------------------

async function measureMemory(cdp) {
  await cdp.send("HeapProfiler.collectGarbage");
  await new Promise((r) => setTimeout(r, 100));
  await cdp.send("HeapProfiler.collectGarbage");
  const { usedSize } = await cdp.send("Runtime.getHeapUsage");
  return usedSize;
}

const memoryBenchmarks = [
  {
    id: "21_ready-memory",
    label: "ready memory",
    run: async () => {},
  },
  {
    id: "22_run-memory",
    label: "run memory",
    run: async (page) => {
      await page.click("#run");
      await waitForRowCount(page, 1000);
    },
  },
  {
    id: "25_run-clear-memory",
    label: "creating/clearing 1k rows (5 cycles)",
    run: async (page) => {
      for (let i = 0; i < 5; i++) {
        await page.click("#run");
        await waitForRowCount(page, 1000);
        await page.click("#clear");
        await waitForRowCount(page, 0);
      }
    },
  },
];

// ---------------------------------------------------------------------------
// Runner
// ---------------------------------------------------------------------------

async function runTimingBenchmarks(browser) {
  const results = [];

  for (const bench of timingBenchmarks) {
    const totalRuns = bench.warmup + ITERATIONS;
    console.error(`  ${bench.id} (${bench.label}): ${bench.warmup} warmup + ${ITERATIONS} measured...`);
    const durations = [];

    for (let i = 0; i < totalRuns; i++) {
      const page = await browser.newPage();
      const cdp = await page.context().newCDPSession(page);

      await page.goto(PREVIEW_URL);
      await waitForReady(page);

      if (bench.setup) {
        await bench.setup(page);
        await page.evaluate(
          () => new Promise((r) => requestAnimationFrame(r)),
        );
      }

      // Apply CPU throttling for the measured action
      await setCPUThrottling(cdp, bench.cpuThrottle);

      const duration = await measureClick(page, bench.action, bench.wait);

      // Reset throttling
      await setCPUThrottling(cdp, undefined);

      if (i >= bench.warmup) {
        durations.push(duration);
      }

      await cdp.detach();
      await page.close();
    }

    const value = parseFloat(median(durations).toFixed(2));
    results.push({ name: bench.id, unit: "ms", value });
    console.error(`    -> ${value} ms (median of ${durations.length})`);
  }

  return results;
}

async function runMemoryBenchmarks(browser) {
  const results = [];

  for (const bench of memoryBenchmarks) {
    console.error(`  ${bench.id} (${bench.label})...`);
    const measurements = [];

    for (let i = 0; i < 3; i++) {
      const page = await browser.newPage();
      const cdp = await page.context().newCDPSession(page);

      await page.goto(PREVIEW_URL);
      await waitForReady(page);

      await bench.run(page);

      const memBytes = await measureMemory(cdp);
      measurements.push(memBytes);

      await cdp.detach();
      await page.close();
    }

    const value = parseFloat((median(measurements) / 1024).toFixed(1));
    results.push({ name: bench.id, unit: "kB", value });
    console.error(`    -> ${value} kB (median of ${measurements.length})`);
  }

  return results;
}

// ---------------------------------------------------------------------------
// Main
// ---------------------------------------------------------------------------

async function main() {
  build();

  console.error("Starting preview server...");
  const previewProc = await startPreview();
  console.error(`Preview server running on ${PREVIEW_URL}`);

  try {
    const browser = await chromium.launch({ headless: true });

    console.error("");
    console.error("  Performance Benchmark");
    console.error("  ─────────────────────");
    console.error("");
    console.error("  Timing:");

    const timingResults = await runTimingBenchmarks(browser);

    console.error("");
    console.error("  Memory:");

    const memoryResults = await runMemoryBenchmarks(browser);

    await browser.close();

    const allResults = [...timingResults, ...memoryResults];

    console.error("");
    console.error("  Summary");
    console.error("  ───────");
    console.error("");

    const nameWidth = Math.max(...allResults.map((r) => r.name.length));
    for (const r of allResults) {
      const valueStr = `${r.value} ${r.unit}`;
      console.error(`  ${r.name.padEnd(nameWidth)}   ${valueStr.padStart(12)}`);
    }
    console.error("");

    console.log(JSON.stringify(allResults, null, 2));
  } finally {
    previewProc.kill();
  }
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});

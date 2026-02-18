#!/usr/bin/env node

// Builds the benchmark app via `vite build`, serves it with `vite preview`,
// then runs js-framework-benchmark-style tests in Chromium.
//
// CPU timings follow the upstream krausest approach:
// - Trace around exactly one benchmark click
// - Extract EventDispatch/Commit events from trace
// - Compute total duration from click to commit end
//
// Reference implementation:
// https://github.com/krausest/js-framework-benchmark/tree/master/webdriver-ts/src
//
// Outputs JSON in github-action-benchmark's "customSmallerIsBetter" format.
//
// Usage: node scripts/measure-perf.mjs
//        node scripts/measure-perf.mjs --iterations 5

import { spawn, spawnSync } from "node:child_process";
import { resolve, dirname } from "node:path";
import { fileURLToPath } from "node:url";
import puppeteer from "puppeteer";

const __dirname = dirname(fileURLToPath(import.meta.url));
const projectRoot = resolve(__dirname, "..");

const ITERATIONS = parseInt(
  process.argv.find((_, i, a) => a[i - 1] === "--iterations") ?? "5",
  10,
);
const PREVIEW_PORT = 4173;
const PREVIEW_URL = `http://localhost:${PREVIEW_PORT}`;
const START_LOGIC_EVENT = "click";

const TRACE_CATEGORIES = [
  "disabled-by-default-v8.cpu_profiler",
  "blink.user_timing",
  "devtools.timeline",
  "disabled-by-default-devtools.timeline",
];

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

function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

async function waitForReady(page) {
  await page.waitForSelector("#app[data-ready='true']", { timeout: 30_000 });
}

async function clickElement(page, selector) {
  const element = await page.$(selector);
  if (!element) {
    throw new Error(`Element not found for click: ${selector}`);
  }
  try {
    await element.click();
  } finally {
    await element.dispose();
  }
}

async function checkElementExists(page, selector) {
  await page.waitForSelector(selector, { timeout: 30_000 });
}

async function checkElementNotExists(page, selector) {
  await page.waitForFunction(
    (selector) => !document.querySelector(selector),
    { timeout: 30_000 },
    selector,
  );
}

async function checkElementContainsText(page, selector, expectedText) {
  await page.waitForFunction(
    ({ selector, expectedText }) => {
      const el = document.querySelector(selector);
      return !!el && (el.textContent ?? "").includes(expectedText);
    },
    { timeout: 30_000 },
    { selector, expectedText },
  );
}

async function checkElementHasClass(page, selector, className) {
  await page.waitForFunction(
    ({ selector, className }) => {
      const el = document.querySelector(selector);
      return !!el && el.classList.contains(className);
    },
    { timeout: 30_000 },
    { selector, className },
  );
}

async function checkCountForSelector(page, selector, expectedCount) {
  await page.waitForFunction(
    ({ selector, expectedCount }) =>
      document.querySelectorAll(selector).length === expectedCount,
    { timeout: 30_000 },
    { selector, expectedCount },
  );
}

async function waitForRowCount(page, expected) {
  await page.waitForFunction(
    (n) => document.querySelectorAll("#tbody tr").length === n,
    { timeout: 30_000 },
    expected,
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

async function startTrace(cdp) {
  await cdp.send("Tracing.start", {
    categories: TRACE_CATEGORIES.join(","),
    transferMode: "ReturnAsStream",
  });
}

async function stopTrace(cdp) {
  return new Promise((resolve, reject) => {
    const onComplete = async ({ stream }) => {
      try {
        let traceData = "";
        // eslint-disable-next-line no-constant-condition
        while (true) {
          const chunk = await cdp.send("IO.read", { handle: stream });
          traceData += chunk.data ?? "";
          if (chunk.eof) break;
        }
        await cdp.send("IO.close", { handle: stream });
        const parsed = JSON.parse(traceData);
        resolve(parsed.traceEvents ?? []);
      } catch (err) {
        reject(err);
      } finally {
        cdp.off("Tracing.tracingComplete", onComplete);
      }
    };

    cdp.on("Tracing.tracingComplete", onComplete);
    cdp.send("Tracing.end").catch((err) => {
      cdp.off("Tracing.tracingComplete", onComplete);
      reject(err);
    });
  });
}

function extractRelevantEvents(entries, startLogicEvent) {
  const filteredEvents = [];

  for (const e of entries) {
    if (e.name === "EventDispatch") {
      const type = e.args?.data?.type;
      if (type === startLogicEvent) {
        filteredEvents.push({
          type: "startLogicEvent",
          ts: +e.ts,
          dur: +e.dur,
          end: +e.ts + +e.dur,
          pid: e.pid,
        });
      }
      if (type === "click") {
        filteredEvents.push({
          type: "click",
          ts: +e.ts,
          dur: +e.dur,
          end: +e.ts + +e.dur,
          pid: e.pid,
        });
      } else if (type === "mousedown") {
        filteredEvents.push({
          type: "mousedown",
          ts: +e.ts,
          dur: +e.dur,
          end: +e.ts + +e.dur,
          pid: e.pid,
        });
      } else if (type === "pointerup") {
        filteredEvents.push({
          type: "pointerup",
          ts: +e.ts,
          dur: +e.dur,
          end: +e.ts + +e.dur,
          pid: e.pid,
        });
      }
    } else if (e.name === "Layout" && e.ph === "X") {
      filteredEvents.push({ type: "layout", ts: +e.ts, dur: +e.dur, end: +e.ts + +e.dur, pid: e.pid });
    } else if (e.name === "FunctionCall" && e.ph === "X") {
      filteredEvents.push({ type: "functioncall", ts: +e.ts, dur: +e.dur, end: +e.ts + +e.dur, pid: e.pid });
    } else if (e.name === "HitTest" && e.ph === "X") {
      filteredEvents.push({ type: "hittest", ts: +e.ts, dur: +e.dur, end: +e.ts + +e.dur, pid: e.pid });
    } else if (e.name === "Commit" && e.ph === "X") {
      filteredEvents.push({ type: "commit", ts: +e.ts, dur: +e.dur, end: +e.ts + +e.dur, pid: e.pid });
    } else if (e.name === "Paint" && e.ph === "X") {
      filteredEvents.push({ type: "paint", ts: +e.ts, dur: +e.dur, end: +e.ts + +e.dur, pid: e.pid });
    } else if (e.name === "FireAnimationFrame" && e.ph === "X") {
      filteredEvents.push({ type: "fireAnimationFrame", ts: +e.ts, dur: +e.dur, end: +e.ts + +e.dur, pid: e.pid });
    } else if (e.name === "TimerFire" && e.ph === "X") {
      filteredEvents.push({ type: "timerFire", ts: +e.ts, dur: 0, end: +e.ts, pid: e.pid });
    } else if (e.name === "RequestAnimationFrame") {
      filteredEvents.push({ type: "requestAnimationFrame", ts: +e.ts, dur: 0, end: +e.ts, pid: e.pid });
    }
  }

  return filteredEvents;
}

function computeDurationFromTrace(traceEvents, startLogicEvent = START_LOGIC_EVENT) {
  const events = extractRelevantEvents(traceEvents, startLogicEvent).sort((a, b) => a.end - b.end);
  const mousedowns = events.filter((e) => e.type === "mousedown");
  if (mousedowns.length > 1) {
    throw new Error("at most one mousedown event is expected");
  }

  const clicks = events.filter((e) => e.type === "startLogicEvent");
  if (clicks.length !== 1) {
    throw new Error("exactly one click event is expected");
  }
  const click = clicks[0];
  const pid = click.pid;

  const eventsDuringBenchmark = events.filter((e) => e.ts > click.end || e.type === "click");
  const eventsOnMainThread = eventsDuringBenchmark.filter((e) => e.pid === pid);
  const startFrom = eventsOnMainThread.filter((e) =>
    ["click", "fireAnimationFrame", "timerFire", "layout", "functioncall"].includes(e.type),
  );
  const startFromEvent = startFrom.at(-1) ?? click;

  const commits = eventsOnMainThread.filter((e) => e.type === "commit");
  if (commits.length === 0) {
    throw new Error("No commit event found");
  }
  let commit = commits.find((e) => e.ts > startFromEvent.end);
  if (!commit) {
    commit = commits.at(-1);
  }

  let duration = (commit.end - click.ts) / 1000.0;

  // Upstream correction for unusual RAF -> FireAnimationFrame delay
  const layouts = eventsOnMainThread.filter((e) => e.type === "layout");
  const rafsWithinClick = events.filter(
    (e) => e.type === "requestAnimationFrame" && e.ts >= click.ts && e.ts <= click.end,
  );
  const fafs = events.filter(
    (e) => e.type === "fireAnimationFrame" && e.ts >= click.ts && e.ts < commit.ts,
  );

  if (rafsWithinClick.length === 1 && fafs.length === 1) {
    const waitDelay = (fafs[0].ts - click.end) / 1000.0;
    if (waitDelay > 16) {
      const hasLayoutBeforeFaf = layouts.some((e) => e.ts < fafs[0].ts);
      if (!hasLayoutBeforeFaf) {
        duration -= waitDelay - 16;
      }
    }
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
    additionalRuns: 0,
    cpuThrottle: undefined,
    init: async (page) => {
      await checkElementExists(page, "#run");
      for (let i = 0; i < 5; i++) {
        await clickElement(page, "#run");
        await checkElementContainsText(page, "#tbody tr:nth-of-type(1) td:nth-of-type(1)", String(i * 1000 + 1));
        await clickElement(page, "#clear");
        await checkElementNotExists(page, "#tbody tr:nth-of-type(1000) td:nth-of-type(1)");
      }
    },
    run: async (page) => {
      await clickElement(page, "#run");
      await checkElementContainsText(page, "#tbody tr:nth-of-type(1000) td:nth-of-type(1)", String((5 + 1) * 1000));
    },
  },
  {
    id: "02_replace1k",
    label: "replace all rows",
    warmup: 5,
    additionalRuns: 0,
    cpuThrottle: undefined,
    init: async (page) => {
      await checkElementExists(page, "#run");
      for (let i = 0; i < 5; i++) {
        await clickElement(page, "#run");
        await checkElementContainsText(page, "#tbody tr:nth-of-type(1) td:nth-of-type(1)", String(i * 1000 + 1));
      }
    },
    run: async (page) => {
      await clickElement(page, "#run");
      await checkElementContainsText(page, "#tbody tr:nth-of-type(1) td:nth-of-type(1)", String(5 * 1000 + 1));
    },
  },
  {
    id: "03_update10th1k_x16",
    label: "partial update",
    warmup: 3,
    additionalRuns: 0,
    cpuThrottle: 4,
    init: async (page) => {
      await checkElementExists(page, "#run");
      await clickElement(page, "#run");
      await checkElementExists(page, "#tbody tr:nth-of-type(1000) td:nth-of-type(1)");
      for (let i = 0; i < 3; i++) {
        await clickElement(page, "#update");
        await checkElementContainsText(page, "#tbody tr:nth-of-type(991) td:nth-of-type(2) a", " !!!".repeat(i + 1));
      }
    },
    run: async (page) => {
      await clickElement(page, "#update");
      await checkElementContainsText(page, "#tbody tr:nth-of-type(991) td:nth-of-type(2) a", " !!!".repeat(4));
    },
  },
  {
    id: "04_select1k",
    label: "select row",
    warmup: 5,
    additionalRuns: 10,
    cpuThrottle: 4,
    init: async (page) => {
      await checkElementExists(page, "#run");
      await clickElement(page, "#run");
      await checkElementContainsText(page, "#tbody tr:nth-of-type(1000) td:nth-of-type(1)", "1000");
      await clickElement(page, "#tbody tr:nth-of-type(5) td:nth-of-type(2) a");
      await checkElementHasClass(page, "#tbody tr:nth-of-type(5)", "danger");
      await checkCountForSelector(page, "#tbody tr.danger", 1);
    },
    run: async (page) => {
      await clickElement(page, "#tbody tr:nth-of-type(2) td:nth-of-type(2) a");
      await checkElementHasClass(page, "#tbody tr:nth-of-type(2)", "danger");
    },
  },
  {
    id: "05_swap1k",
    label: "swap rows",
    warmup: 5,
    additionalRuns: 0,
    cpuThrottle: 4,
    init: async (page) => {
      await checkElementExists(page, "#run");
      await clickElement(page, "#run");
      await checkElementExists(page, "#tbody tr:nth-of-type(1000) td:nth-of-type(1)");
      for (let i = 0; i <= 5; i++) {
        const text = i % 2 === 0 ? "2" : "999";
        await clickElement(page, "#swaprows");
        await checkElementContainsText(page, "#tbody tr:nth-of-type(999) td:nth-of-type(1)", text);
      }
    },
    run: async (page) => {
      await clickElement(page, "#swaprows");
      const text999 = 5 % 2 === 0 ? "999" : "2";
      const text2 = 5 % 2 === 0 ? "2" : "999";
      await checkElementContainsText(page, "#tbody tr:nth-of-type(999) td:nth-of-type(1)", text999);
      await checkElementContainsText(page, "#tbody tr:nth-of-type(2) td:nth-of-type(1)", text2);
    },
  },
  {
    id: "06_remove-one-1k",
    label: "remove row",
    warmup: 5,
    additionalRuns: 0,
    cpuThrottle: 2,
    init: async (page) => {
      const rowsToSkip = 4;
      await checkElementExists(page, "#run");
      await clickElement(page, "#run");
      await checkElementExists(page, "#tbody tr:nth-of-type(1000) td:nth-of-type(1)");
      for (let i = 0; i < 5; i++) {
        const rowToClick = 5 - i + rowsToSkip;
        await checkElementContainsText(
          page,
          `#tbody tr:nth-of-type(${rowToClick}) td:nth-of-type(1)`,
          String(rowToClick),
        );
        await clickElement(
          page,
          `#tbody tr:nth-of-type(${rowToClick}) td:nth-of-type(3) a span:nth-of-type(1)`,
        );
        await checkElementContainsText(
          page,
          `#tbody tr:nth-of-type(${rowToClick}) td:nth-of-type(1)`,
          String(rowsToSkip + 5 + 1),
        );
      }
      await checkElementContainsText(page, `#tbody tr:nth-of-type(${rowsToSkip + 1}) td:nth-of-type(1)`, String(rowsToSkip + 5 + 1));
      await checkElementContainsText(page, `#tbody tr:nth-of-type(${rowsToSkip}) td:nth-of-type(1)`, String(rowsToSkip));
      await checkElementContainsText(
        page,
        `#tbody tr:nth-of-type(${rowsToSkip + 2}) td:nth-of-type(1)`,
        String(rowsToSkip + 5 + 2),
      );
      await clickElement(page, `#tbody tr:nth-of-type(${rowsToSkip + 2}) td:nth-of-type(3) a span:nth-of-type(1)`);
      await checkElementContainsText(
        page,
        `#tbody tr:nth-of-type(${rowsToSkip + 2}) td:nth-of-type(1)`,
        String(rowsToSkip + 5 + 3),
      );
    },
    run: async (page) => {
      const rowsToSkip = 4;
      await clickElement(page, `#tbody tr:nth-of-type(${rowsToSkip}) td:nth-of-type(3) a span:nth-of-type(1)`);
      await checkElementContainsText(
        page,
        `#tbody tr:nth-of-type(${rowsToSkip}) td:nth-of-type(1)`,
        String(rowsToSkip + 5 + 1),
      );
    },
  },
  // Temporarily disabled to keep CI runtime reasonable.
  // {
  //   id: "07_create10k",
  //   label: "create many rows",
  //   warmup: 5,
  //   additionalRuns: 0,
  //   cpuThrottle: undefined,
  //   init: async (page) => {
  //     await checkElementExists(page, "#run");
  //     for (let i = 0; i < 5; i++) {
  //       await clickElement(page, "#run");
  //       await checkElementContainsText(page, "#tbody tr:nth-of-type(1) td:nth-of-type(1)", String(i * 1000 + 1));
  //       await clickElement(page, "#clear");
  //       await checkElementNotExists(page, "#tbody tr:nth-of-type(1000) td:nth-of-type(1)");
  //     }
  //   },
  //   run: async (page) => {
  //     await clickElement(page, "#runlots");
  //     await checkElementExists(page, "#tbody tr:nth-of-type(10000) td:nth-of-type(2) a");
  //   },
  // },
  {
    id: "08_create1k-after1k_x2",
    label: "append rows to large table",
    warmup: 5,
    additionalRuns: 0,
    cpuThrottle: undefined,
    init: async (page) => {
      await checkElementExists(page, "#run");
      for (let i = 0; i < 5; i++) {
        await clickElement(page, "#run");
        await checkElementContainsText(page, "#tbody tr:nth-of-type(1) td:nth-of-type(1)", String(i * 1000 + 1));
        await clickElement(page, "#clear");
        await checkElementNotExists(page, "#tbody tr:nth-of-type(1000) td:nth-of-type(1)");
      }
      await clickElement(page, "#run");
      await checkElementExists(page, "#tbody tr:nth-of-type(1000) td:nth-of-type(1)");
    },
    run: async (page) => {
      await clickElement(page, "#add");
      await checkElementExists(page, "#tbody tr:nth-of-type(2000) td:nth-of-type(1)");
    },
  },
  {
    id: "09_clear1k_x8",
    label: "clear rows",
    warmup: 5,
    additionalRuns: 0,
    cpuThrottle: 4,
    init: async (page) => {
      await checkElementExists(page, "#run");
      for (let i = 0; i < 5; i++) {
        await clickElement(page, "#run");
        await checkElementContainsText(page, "#tbody tr:nth-of-type(1) td:nth-of-type(1)", String(i * 1000 + 1));
        await clickElement(page, "#clear");
        await checkElementNotExists(page, "#tbody tr:nth-of-type(1000) td:nth-of-type(1)");
      }
      await clickElement(page, "#run");
      await checkElementContainsText(page, "#tbody tr:nth-of-type(1) td:nth-of-type(1)", String(5 * 1000 + 1));
    },
    run: async (page) => {
      await clickElement(page, "#clear");
      await checkElementNotExists(page, "#tbody tr:nth-of-type(1000) td:nth-of-type(1)");
    },
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
    init: async (page) => {
      await checkElementExists(page, "#run");
    },
    run: async () => {},
  },
  {
    id: "22_run-memory",
    label: "run memory",
    init: async (page) => {
      await checkElementExists(page, "#run");
    },
    run: async (page) => {
      await clickElement(page, "#run");
      await checkElementExists(page, "#tbody tr:nth-of-type(1) td:nth-of-type(2) a");
    },
  },
  {
    id: "25_run-clear-memory",
    label: "creating/clearing 1k rows (5 cycles)",
    init: async (page) => {
      await checkElementExists(page, "#run");
    },
    run: async (page) => {
      for (let i = 0; i < 5; i++) {
        await clickElement(page, "#run");
        await checkElementContainsText(page, "#tbody tr:nth-of-type(1000) td:nth-of-type(1)", String(1000 * (i + 1)));
        await clickElement(page, "#clear");
        await checkElementNotExists(page, "#tbody tr:nth-of-type(1000) td:nth-of-type(1)");
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
    const runCount = ITERATIONS + (bench.additionalRuns ?? 0);
    console.error(`  ${bench.id} (${bench.label}): warmup in init, ${runCount} measured...`);
    const durations = [];

    for (let i = 0; i < runCount; i++) {
      const page = await browser.newPage();
      const cdp = await page.target().createCDPSession();

      await page.goto(PREVIEW_URL, { waitUntil: "networkidle0" });
      await waitForReady(page);
      await bench.init(page);

      // Apply CPU throttling for the measured action
      await setCPUThrottling(cdp, bench.cpuThrottle);
      await startTrace(cdp);
      await sleep(50);
      await cdp.send("HeapProfiler.collectGarbage").catch(() => {});
      await bench.run(page);
      await sleep(100);
      const traceEvents = await stopTrace(cdp);
      const duration = computeDurationFromTrace(traceEvents, START_LOGIC_EVENT);

      // Reset throttling
      await setCPUThrottling(cdp, undefined);
      durations.push(duration);

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
      const cdp = await page.target().createCDPSession();

      await page.goto(PREVIEW_URL, { waitUntil: "networkidle0" });
      await waitForReady(page);
      await bench.init(page);
      await bench.run(page);
      await cdp.send("HeapProfiler.collectGarbage").catch(() => {});
      await sleep(40);
      const memFromUA = await page.evaluate(async () => {
        if (typeof performance.measureUserAgentSpecificMemory !== "function") {
          return null;
        }
        const result = await performance.measureUserAgentSpecificMemory();
        return result.bytes / 1024 / 1024;
      });
      if (memFromUA != null) {
        measurements.push(memFromUA);
      } else {
        const memBytes = await measureMemory(cdp);
        measurements.push(memBytes / 1024 / 1024);
      }

      await cdp.detach();
      await page.close();
    }

    const value = parseFloat(median(measurements).toFixed(2));
    results.push({ name: bench.id, unit: "MB", value });
    console.error(`    -> ${value} MB (median of ${measurements.length})`);
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
    const browser = await puppeteer.launch({ headless: true });

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

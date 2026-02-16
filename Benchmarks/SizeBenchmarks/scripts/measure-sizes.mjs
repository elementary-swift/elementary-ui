#!/usr/bin/env node

// Builds each benchmark target via `vite build`, parses the output for .wasm
// file sizes (raw + gzip), and outputs JSON in github-action-benchmark's
// "customSmallerIsBetter" format.
//
// Usage: node scripts/measure-sizes.mjs
//        node scripts/measure-sizes.mjs HelloWorld Counter  (subset)

import { execFileSync } from "node:child_process";
import { resolve, dirname } from "node:path";
import { fileURLToPath } from "node:url";

const __dirname = dirname(fileURLToPath(import.meta.url));
const projectRoot = resolve(__dirname, "..");

const ALL_TARGETS = ["HelloWorld", "Counter", "Animations"];
const targets = process.argv.length > 2 ? process.argv.slice(2) : ALL_TARGETS;

// Vite output lines look like:
//   dist/HelloWorld/assets/HelloWorld-D4RrNIe6.wasm  3,219.44 kB │ gzip: 1,143.90 kB
//   dist/Counter/assets/Counter-CiP1900W.wasm          326.71 kB │ gzip:   137.18 kB
// Numbers may contain commas as thousands separators.
const SIZE_LINE_RE =
  /(\S+\.wasm)\s+([\d,]+(?:\.\d+)?)\s+(kB|B)\s+│\s+gzip:\s+([\d,]+(?:\.\d+)?)\s+(kB|B)/;

function parseSize(value, unit) {
  const num = parseFloat(value.replace(/,/g, ""));
  return Math.round(unit === "kB" ? num * 1000 : num);
}

function extractProductName(filePath) {
  const filename = filePath.split("/").pop();
  const match = filename.match(/^(.+?)(-[A-Za-z0-9_-]+)?\.wasm$/);
  return match ? match[1] : filename.replace(".wasm", "");
}

function buildAndMeasure(product) {
  console.error(`Building ${product}...`);

  const output = execFileSync(
    resolve(projectRoot, "node_modules/.bin/vite"),
    ["build"],
    {
      cwd: projectRoot,
      env: { ...process.env, BENCH_PRODUCT: product },
      encoding: "utf-8",
      stdio: ["ignore", "pipe", "pipe"],
      timeout: 600_000,
    }
  );

  // Vite prints the size table to stdout
  const combined = output;
  for (const line of combined.split("\n")) {
    const m = line.match(SIZE_LINE_RE);
    if (!m) continue;

    const [, filePath, rawValue, rawUnit, gzipValue, gzipUnit] = m;
    const name = extractProductName(filePath);
    const rawBytes = parseSize(rawValue, rawUnit);
    const gzipBytes = parseSize(gzipValue, gzipUnit);

    return { name, rawBytes, gzipBytes };
  }

  throw new Error(`No .wasm file found in vite build output for ${product}`);
}

function formatBytes(bytes) {
  return `${(bytes / 1000).toFixed(2)} kB`;
}

function pad(str, len) {
  return str.padStart(len);
}

// Build each target sequentially and collect results
const measurements = [];
for (const target of targets) {
  measurements.push(buildAndMeasure(target));
}

// Human-readable summary to stderr
const nameWidth = Math.max(...measurements.map((m) => m.name.length));
const rawStrs = measurements.map((m) => formatBytes(m.rawBytes));
const gzipStrs = measurements.map((m) => formatBytes(m.gzipBytes));
const rawWidth = Math.max(...rawStrs.map((s) => s.length), 3);
const gzipWidth = Math.max(...gzipStrs.map((s) => s.length), 4);

console.error("");
console.error("  WASM Size Benchmark Results");
console.error("");
console.error(
  `  ${"Target".padEnd(nameWidth)}   ${pad("Raw", rawWidth)}   ${pad(
    "Gzip",
    gzipWidth
  )}`
);
console.error(
  `  ${"─".repeat(nameWidth)}   ${"─".repeat(rawWidth)}   ${"─".repeat(
    gzipWidth
  )}`
);
for (let i = 0; i < measurements.length; i++) {
  const m = measurements[i];
  console.error(
    `  ${m.name.padEnd(nameWidth)}   ${pad(rawStrs[i], rawWidth)}   ${pad(
      gzipStrs[i],
      gzipWidth
    )}`
  );
}
console.error("");

// Machine-readable JSON to stdout (gzip only — the metric that matters for users)
const benchmarkResults = measurements.map((m) => ({
  name: m.name,
  unit: "kB",
  value: parseFloat((m.gzipBytes / 1000).toFixed(2)),
}));

console.log(JSON.stringify(benchmarkResults, null, 2));

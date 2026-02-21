#!/usr/bin/env node

import { readFileSync, existsSync } from "node:fs";
import { resolve } from "node:path";

const bridgeJSPath = resolve(process.cwd(), "src/generated/bridge-js.js");

if (!existsSync(bridgeJSPath)) {
  console.error("Missing BridgeJS runtime file: src/generated/bridge-js.js");
  console.error("Run Scripts/fold-bridgejs-runtime.sh before building BrowserRuntime.");
  process.exit(1);
}

const source = readFileSync(bridgeJSPath, "utf8");
if (source.includes("Unexpected call to BridgeJS function")) {
  console.error("BrowserRuntime is still using fallback BridgeJS stubs.");
  console.error("Run Scripts/fold-bridgejs-runtime.sh with CLI-generated bridge-js.js output.");
  process.exit(1);
}

import { readFileSync } from "node:fs";
import { expect, test } from "@playwright/test";

const source = readFileSync(
  new URL("../../../Sources/ElementaryWebComponents/JavaScript/custom-elements.js", import.meta.url),
  "utf8"
).replace("export function", "function").replaceAll("import.meta.hot", "true");

test.beforeEach(async ({ page }) => {
  await page.addScriptTag({ content: source });
});

test("reloads when observed attribute names change", async ({ page }) => {
  const navigation = page.waitForEvent("framenavigated");
  await page.evaluate(() => {
    const define = (globalThis as any).defineCustomElement;
    define("test-attributes", { observedAttributes: ["count"] });
    define("test-attributes", { observedAttributes: ["value"] });
  });
  await navigation;
});

test("reconstructs shadow-tree instances and stops tracking disconnected hosts", async ({ page }) => {
  const events = await page.evaluate(() => {
    const define = (globalThis as any).defineCustomElement;
    const events: string[] = [];
    const implementation = (version: string) => ({
      observedAttributes: ["count"],
      connect(element: HTMLElement) { events.push(`${version}:connect:${element.id}`); },
      disconnect(element: HTMLElement) { events.push(`${version}:disconnect:${element.id}`); },
      setAttribute(element: HTMLElement) { events.push(`${version}:attribute:${element.id}`); },
    });
    define("test-nested", implementation("old"));
    const parent = document.createElement("div");
    document.body.append(parent);
    const root = parent.attachShadow({ mode: "closed" });
    root.innerHTML = '<test-nested id="connected"></test-nested><test-nested id="removed"></test-nested>';
    root.lastElementChild!.remove();
    events.length = 0;
    define("test-nested", implementation("new"));
    root.firstElementChild!.setAttribute("count", "2");
    parent.remove();
    define("test-nested", implementation("latest"));
    return events;
  });
  expect(events).toEqual([
    "old:disconnect:connected",
    "new:connect:connected",
    "new:attribute:connected",
    "new:disconnect:connected",
  ]);
});

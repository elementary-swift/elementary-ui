import { expect, type Locator, type Page, test } from "@playwright/test";

async function load(page: Page) {
  await page.goto("http://127.0.0.1:4174");
  await page.waitForFunction(() => (globalThis as any).__elementaryWebComponentsReady === true);
}

function value(host: Locator) {
  return host.locator("#value");
}

async function replaceCounter(page: Page, hotReload: boolean) {
  return page.evaluate((hotReload) => {
    (globalThis as any).__elementaryHotReload = hotReload;
    return (globalThis as any).__elementaryReplaceCounter() as boolean;
  }, hotReload);
}

test("upgrades existing markup and applies typed attributes", async ({ page }) => {
  await load(page);
  const host = page.locator("#pre-upgrade");

  await expect(host.evaluate((element) => element.shadowRoot !== null)).resolves.toBe(true);
  await expect(value(host)).toHaveText("5:0:ready");

  await host.evaluate((element) => element.setAttribute("count", "8"));
  await expect(value(host)).toHaveText("8:0:ready");

  await host.evaluate((element) => element.setAttribute("count", "invalid"));
  await expect(value(host)).toHaveText("8:0:ready");

  await host.evaluate((element) => {
    element.removeAttribute("count");
    element.removeAttribute("label");
  });
  await expect(value(host)).toHaveText("1:0:nil");
});

test("projects native slots and preserves light DOM children", async ({ page }) => {
  await load(page);

  const projected = await page.locator("#pre-upgrade").evaluate((element) => {
    const slots = [...element.shadowRoot!.querySelectorAll("slot")] as HTMLSlotElement[];
    return Object.fromEntries(
      slots.map((slot) => [slot.name || "default", slot.assignedElements().map((child) => child.id)])
    );
  });
  expect(projected).toEqual({ default: ["projected"], note: ["note"] });

  const light = page.locator("#light");
  await expect(light.evaluate((element) => element.shadowRoot)).resolves.toBeNull();
  await expect(light.locator("#authored-light-child")).toHaveText("Authored child");
  await expect(value(light)).toHaveText("2:0:nil");

  await light.locator("#increment").click();
  await expect(value(light)).toHaveText("2:1:nil");
  await light.evaluate((element) => document.querySelector("#move-target")!.append(element));
  await expect(light.locator("#authored-light-child")).toHaveText("Authored child");
  await expect(value(light)).toHaveText("2:0:nil");
});

test("shares and orders constructable stylesheets", async ({ page }) => {
  await load(page);

  const result = await page.evaluate(() => {
    const sheets = (id: string) => document.querySelector(id)!.shadowRoot!.adoptedStyleSheets;
    const color = (id: string) => getComputedStyle(document.querySelector(id)!).color;
    const counter = sheets("#pre-upgrade");
    const styled = sheets("#styled");
    const shared = sheets("#shared");

    return {
      counterCount: counter.length,
      styledCount: styled.length,
      sharedCount: shared.length,
      unstyledCount: sheets("#unstyled").length,
      sharedIdentity: counter[0] === styled[0] && styled[0] === shared[0],
      counterColor: color("#pre-upgrade"),
      styledColor: color("#styled"),
      sharedColor: color("#shared"),
    };
  });

  expect(result).toEqual({
    counterCount: 1,
    styledCount: 2,
    sharedCount: 1,
    unstyledCount: 0,
    sharedIdentity: true,
    counterColor: "rgb(10, 20, 30)",
    styledColor: "rgb(40, 50, 60)",
    sharedColor: "rgb(10, 20, 30)",
  });
});

test("isolates instances and preserves only state-preserving moves", async ({ page }) => {
  await load(page);

  await page.evaluate(() => {
    const second = document.createElement("test-counter");
    second.id = "second";
    second.setAttribute("count", "12");
    document.body.append(second);
  });

  const first = page.locator("#pre-upgrade");
  const second = page.locator("#second");
  await first.locator("#increment").click();
  await expect(value(first)).toHaveText("5:1:ready");
  await expect(value(second)).toHaveText("12:0:nil");

  await page.evaluate(() => {
    (document.querySelector("#move-target") as any).moveBefore(document.querySelector("#pre-upgrade"), null);
  });
  await expect(value(first)).toHaveText("5:1:ready");

  await first.evaluate((element) => document.body.append(element));
  await expect(value(first)).toHaveText("5:0:ready");
});

test("maps native registration failures to the Swift error", async ({ page }) => {
  await load(page);
  const host = page.locator("#pre-upgrade");
  await host.locator("#increment").click();
  await expect(value(host)).toHaveText("5:1:ready");

  expect(await replaceCounter(page, false)).toBe(false);
  await expect(value(host)).toHaveText("5:1:ready");
  expect(await page.evaluate(() => (globalThis as any).__elementaryInvalidRegistrationFailed)).toBe(true);
});

test("replaces live instances during hot reload", async ({ page }) => {
  await load(page);
  const host = page.locator("#pre-upgrade");
  await host.locator("#increment").click();
  await expect(value(host)).toHaveText("5:1:ready");

  expect(await replaceCounter(page, true)).toBe(true);
  await expect(value(host)).toHaveText("5:0:ready");
  await expect(
    host.evaluate((element) => ({
      count: element.shadowRoot!.adoptedStyleSheets.length,
      color: getComputedStyle(element).color,
    }))
  ).resolves.toEqual({ count: 2, color: "rgb(70, 80, 90)" });
});

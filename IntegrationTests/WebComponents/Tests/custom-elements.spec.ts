import { expect, test } from "@playwright/test";

async function load(page: import("@playwright/test").Page, port = 4174) {
  await page.goto(`http://127.0.0.1:${port}`);
  await page.waitForFunction(
    () => (globalThis as any).__elementaryWebComponentsReady === true
  );
}

test("upgrades existing markup and applies typed attributes", async ({ page }) => {
  await load(page);
  const host = page.locator("#pre-upgrade");

  expect(await host.evaluate((element) => element.querySelector("#value"))).toBeNull();
  expect(await host.evaluate((element) => element.shadowRoot !== null)).toBe(true);
  await expect
    .poll(() => host.evaluate((e) => e.shadowRoot?.querySelector("#value")?.textContent))
    .toBe("5:0:ready");

  await host.evaluate((element) => element.setAttribute("count", "8"));
  await expect
    .poll(() => host.evaluate((e) => e.shadowRoot?.querySelector("#value")?.textContent))
    .toBe("8:0:ready");

  await host.evaluate((element) => element.setAttribute("count", "invalid"));
  await expect
    .poll(() => host.evaluate((e) => e.shadowRoot?.querySelector("#value")?.textContent))
    .toBe("8:0:ready");

  await host.evaluate((element) => {
    element.removeAttribute("count");
    element.removeAttribute("label");
  });
  await expect
    .poll(() => host.evaluate((e) => e.shadowRoot?.querySelector("#value")?.textContent))
    .toBe("1:0:nil");
});

test("projects native slots and preserves light DOM children", async ({ page }) => {
  await load(page);

  const projectedText = await page.locator("#pre-upgrade").evaluate((element) => {
    const slot = element.shadowRoot?.querySelector("slot") as HTMLSlotElement;
    return slot.assignedElements().map((child) => child.textContent).join("");
  });
  expect(projectedText).toContain("Projected child");

  const light = page.locator("#light");
  expect(await light.evaluate((element) => element.shadowRoot)).toBeNull();
  await expect(light.locator("#authored-light-child")).toHaveText("Authored child");
  await expect(light.locator("#value")).toHaveText("2:0:nil");

  await light.locator("#increment").click();
  await expect(light.locator("#value")).toHaveText("2:1:nil");
  await light.evaluate((element) => document.querySelector("#move-target")!.append(element));
  await expect(light.locator("#authored-light-child")).toHaveText("Authored child");
  await expect(light.locator("#value")).toHaveCount(1);
  await expect(light.locator("#value")).toHaveText("2:0:nil");
});

test("shares and orders constructable stylesheets", async ({ page }) => {
  await load(page);

  const result = await page.evaluate(() => {
    const counter = document.querySelector("#pre-upgrade")!;
    const styled = document.querySelector("#styled")!;
    const shared = document.querySelector("#shared")!;
    const unstyled = document.querySelector("#unstyled")!;
    const counterSheets = counter.shadowRoot!.adoptedStyleSheets;
    const styledSheets = styled.shadowRoot!.adoptedStyleSheets;
    const sharedSheets = shared.shadowRoot!.adoptedStyleSheets;

    return {
      counterCount: counterSheets.length,
      styledCount: styledSheets.length,
      sharedCount: sharedSheets.length,
      unstyledCount: unstyled.shadowRoot!.adoptedStyleSheets.length,
      sharedIdentity:
        counterSheets[0] === styledSheets[0] &&
        styledSheets[0] === sharedSheets[0],
      counterColor: getComputedStyle(counter).color,
      styledColor: getComputedStyle(styled).color,
      sharedColor: getComputedStyle(shared).color,
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
  await first.evaluate((e) => (e.shadowRoot?.querySelector("#increment") as HTMLElement).click());
  await expect
    .poll(() => first.evaluate((e) => e.shadowRoot?.querySelector("#value")?.textContent))
    .toBe("5:1:ready");
  await expect
    .poll(() => second.evaluate((e) => e.shadowRoot?.querySelector("#value")?.textContent))
    .toBe("12:0:nil");

  await page.evaluate(() => {
    const target = document.querySelector("#move-target")!;
    const element = document.querySelector("#pre-upgrade")!;
    (target as any).moveBefore(element, null);
  });
  await expect
    .poll(() => first.evaluate((e) => e.shadowRoot?.querySelector("#value")?.textContent))
    .toBe("5:1:ready");

  await first.evaluate((element) => {
    document.body.append(element);
  });
  await expect
    .poll(() => first.evaluate((e) => e.shadowRoot?.querySelector("#value")?.textContent))
    .toBe("5:0:ready");
  expect(
    await first.evaluate((e) => e.shadowRoot?.querySelectorAll("#value").length)
  ).toBe(1);
});

test("maps native registration failures to the Swift error", async ({ page }) => {
  await load(page);
  expect(
    await page.evaluate(() => (globalThis as any).__elementaryDuplicateRegistrationFailed)
  ).toBe(true);
  expect(
    await page.evaluate(() => (globalThis as any).__elementaryInvalidRegistrationFailed)
  ).toBe(true);
});

test("replaces live instances during Vite HMR-compatible registration", async ({ page }) => {
  await load(page, 4173);
  // The fixture registers test-counter twice. In development the second registration follows
  // the HMR replacement path and reconstructs the already-upgraded hosts.
  expect(
    await page.evaluate(() => (globalThis as any).__elementaryDuplicateRegistrationFailed)
  ).toBe(false);
  await expect
    .poll(() =>
      page.locator("#pre-upgrade").evaluate(
        (e) => e.shadowRoot?.querySelector("#value")?.textContent
      )
    )
    .toBe("5:0:ready");
  expect(
    await page.locator("#pre-upgrade").evaluate((element) => ({
      count: element.shadowRoot!.adoptedStyleSheets.length,
      color: getComputedStyle(element).color,
    }))
  )    .toEqual({ count: 2, color: "rgb(70, 80, 90)" });
});

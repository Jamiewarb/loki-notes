import { test, expect } from "@playwright/test";
import {
  gotoPanel,
  harness,
  PANEL_IDS,
  expectPanelLoaded,
  type PanelId,
} from "./helpers";

const PRIMARY_NAV: { name: string; id: PanelId }[] = [
  { name: "Daily", id: "daily" },
  { name: "Tasks", id: "tasks" },
  { name: "Search", id: "search" },
  { name: "Types", id: "types" },
  { name: "Settings", id: "settings" },
];

test("default / loads Daily destination", async ({ page }) => {
  await page.goto("/");
  await expectPanelLoaded(page, "daily");
});

test("shell chrome shows loci-shell, sidebar, detail, and inspector", async ({
  page,
}) => {
  await page.goto("/");
  await expect(harness(page, "loci-shell")).toBeVisible();
  await expect(harness(page, "sidebar")).toBeVisible();
  await expect(harness(page, "detail")).toBeVisible();
  await expect(harness(page, "inspector")).toBeVisible();
});

test("?panel=settings deep-links to settings destination", async ({ page }) => {
  await page.goto("/?panel=settings");
  await expectPanelLoaded(page, "settings");
});

for (const { name, id } of PRIMARY_NAV) {
  test(`primary nav ${name} switches destination to ${id}`, async ({ page }) => {
    // Daily is already the default destination — start elsewhere so the click re-renders.
    if (id === "daily") {
      await gotoPanel(page, "settings");
    } else {
      await page.goto("/");
      await expectPanelLoaded(page, "daily");
    }
    await page
      .getByRole("navigation", { name: "Navigate" })
      .getByRole("button", { name })
      .click();
    await expectPanelLoaded(page, id);
  });
}

for (const id of PANEL_IDS) {
  test(`every panel leaves loading — destination is ${id}`, async ({ page }) => {
    await gotoPanel(page, id);
    await expect(harness(page, "destination")).toHaveAttribute(
      "data-destination",
      id,
    );
  });
}

test("pinned rows are visible and enabled", async ({ page }) => {
  await page.goto("/");
  await expect(harness(page, "sidebar")).toBeVisible();
  const inbox = harness(page, "pin-row").filter({ hasText: "Inbox" });
  await expect(inbox).toBeVisible();
  await expect(inbox).toBeEnabled();
});

test("clicking a pin stays on the shell", async ({ page }) => {
  await page.goto("/");
  await expect(harness(page, "loci-shell")).toBeVisible();
  await harness(page, "pin-row").filter({ hasText: "Inbox" }).click();
  await expect(harness(page, "loci-shell")).toBeVisible();
  await expect(harness(page, "sidebar")).toBeVisible();
  await expect(harness(page, "pin-open")).toBeVisible();
  await expect(harness(page, "pin-open")).toContainText("Navigating.open");
});

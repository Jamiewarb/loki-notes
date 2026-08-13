import { expect, test } from "@playwright/test";
import { gotoPanel, harness } from "./helpers";

test("daily note uses deterministic daily/YYYY-MM-DD.md path", async ({ page }) => {
  await gotoPanel(page, "daily");
  await expect(harness(page, "daily-path")).toBeVisible();
  await expect(harness(page, "daily-path")).toHaveText(/daily\/\d{4}-\d{2}-\d{2}\.md/);
});

test("daily note logical id is rendered", async ({ page }) => {
  await gotoPanel(page, "daily");
  await expect(harness(page, "daily-id")).toBeVisible();
  await expect(harness(page, "daily-id")).toHaveText(/daily-\d{4}-\d{2}-\d{2}/);
});

test("idempotent ensure is yes", async ({ page }) => {
  await gotoPanel(page, "daily");
  await expect(harness(page, "daily-idempotent")).toBeVisible();
  await expect(harness(page, "daily-idempotent")).toHaveText("yes");
});

test("day nav prev/today/next match the rendered fixture", async ({ page }) => {
  await gotoPanel(page, "daily");
  await expect(harness(page, "daily-prev")).toBeVisible();
  await expect(harness(page, "daily-today")).toBeVisible();
  await expect(harness(page, "daily-next")).toBeVisible();
  await expect(harness(page, "daily-prev")).toHaveText("2026-08-12");
  await expect(harness(page, "daily-today")).toHaveText("2026-08-13");
  await expect(harness(page, "daily-next")).toHaveText("2026-08-14");
});

test("created-today list has rows", async ({ page }) => {
  await gotoPanel(page, "daily");
  await expect(harness(page, "created-today-row")).not.toHaveCount(0);
});

test("clicking a created-today row reveals detail", async ({ page }) => {
  await gotoPanel(page, "daily");
  const row = harness(page, "created-today-section").getByRole("button", {
    name: /Deep Work Notes/,
  });
  await expect(row).toBeVisible();
  await expect(harness(page, "created-today-detail")).toBeHidden();
  await row.click();
  await expect(harness(page, "created-today-detail")).toBeVisible();
});

test("created-today does not rewrite daily.md", async ({ page }) => {
  await gotoPanel(page, "daily");
  await expect(harness(page, "daily-unchanged")).toBeVisible();
  await expect(harness(page, "daily-unchanged")).toContainText(
    "daily .md unchanged after Page create",
  );
});

test("index is never stored in the vault", async ({ page }) => {
  await gotoPanel(page, "daily");
  await expect(harness(page, "daily-meta").getByText("Index in vault")).toBeVisible();
  await expect(harness(page, "daily-meta").getByText("never", { exact: true })).toBeVisible();
});

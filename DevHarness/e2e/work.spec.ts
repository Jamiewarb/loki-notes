import { expect, test } from "@playwright/test";
import { gotoPanel, harness } from "./helpers";

test("today and open task lists are visible", async ({ page }) => {
  await gotoPanel(page, "tasks");

  const todayList = harness(page, "tasks-today-list");
  await expect(todayList).toBeVisible();
  await expect(todayList).toContainText("Review PR19 Tasks");
  await expect(todayList).toContainText("Seed daily note");

  const openList = harness(page, "tasks-open-list");
  await expect(openList).toBeVisible();
  await expect(openList).toContainText("Review PR19 Tasks");
  await expect(openList).toContainText("Write evidence");
});

test("tasks proof records page toggle completed without persisting checkbox clicks", async ({
  page,
}) => {
  await gotoPanel(page, "tasks");

  const proof = harness(page, "tasks-proof");
  await expect(proof).toBeVisible();
  await expect(proof).toContainText("page toggle → completed ✓");
  await expect(proof).toContainText("daily open task ✓");
  await expect(proof).toContainText("index outside vault ✓");
  await expect(harness(page, "tasks-index-in-vault")).toHaveText("no ✓");
});

test("media attachment paths live under media/", async ({ page }) => {
  await gotoPanel(page, "media");

  await expect(harness(page, "media-image-path")).toBeVisible();
  await expect(harness(page, "media-image-path")).toContainText("media/");
  await expect(harness(page, "media-file-path")).toContainText("media/");
  await expect(harness(page, "media-object-path")).toContainText("media/");
  await expect(harness(page, "media-images-list")).toContainText("hero.png");
  await expect(harness(page, "media-files-list")).toContainText("notes.txt");
});

test("media picker proofs are wired and note body stays vault-relative", async ({
  page,
}) => {
  await gotoPanel(page, "media");

  await expect(harness(page, "media-proof-photos-picker")).toBeVisible();
  await expect(harness(page, "media-proof-photos-picker")).toContainText("wired");
  await expect(harness(page, "media-proof-drag-drop")).toContainText("wired");
  await expect(harness(page, "media-page-body")).toContainText("media/");
  await expect(harness(page, "media-page-body")).not.toContainText("/tmp/");
  await expect(harness(page, "media-proof")).toContainText("photos picker wired ✓");
  await expect(harness(page, "media-proof")).toContainText("drag-drop wired ✓");
  await expect(harness(page, "media-index-in-vault")).toHaveText("no ✓");
});

test("clicking a calendar day updates selection to daily/<key>.md", async ({
  page,
}) => {
  await gotoPanel(page, "calendar");

  const day = harness(page, "calendar-grid").getByRole("button", {
    name: "14",
    exact: true,
  });
  await expect(day).toBeVisible();
  const key = await day.getAttribute("data-day-key");
  await day.click();
  await expect(harness(page, "calendar-selection")).toContainText(
    `daily/${key}.md`,
  );
});

test("capture drain empties inbox and indexes on foreground only", async ({
  page,
}) => {
  await gotoPanel(page, "capture");

  await expect(harness(page, "capture-proof")).toBeVisible();
  await expect(harness(page, "capture-proof-inboxThenDrain")).toHaveText(
    "yes ✓",
  );
  await expect(harness(page, "capture-proof-inboxStagingRemoved")).toHaveText(
    "yes ✓",
  );
  await expect(harness(page, "capture-pending-after")).toHaveText("0");
  await expect(harness(page, "capture-drain-item")).not.toHaveCount(0);
  await expect(harness(page, "capture-proof-indexOutsideVault")).toHaveText(
    "yes ✓",
  );
  await expect(page.getByText("Index on foreground only")).toBeVisible();
});

import { test, expect } from "@playwright/test";
import { gotoPanel, harness } from "./helpers";

test("PARA starter pack surfaces Project, Area, Resource, and Archive", async ({ page }) => {
  await gotoPanel(page, "types");

  await expect(harness(page, "para-types-list")).toBeVisible();
  await expect(harness(page, "para-project-row")).toBeVisible();
  await expect(harness(page, "para-area-row")).toBeVisible();

  const typeList = harness(page, "type-list");
  await expect(typeList).toBeVisible();
  await expect(typeList).toContainText("Project");
  await expect(typeList).toContainText("Area");

  const paraNote = harness(page, "para-types-note");
  await expect(paraNote).toBeVisible();
  await expect(paraNote).toContainText("tag:#resource");
  await expect(paraNote).toContainText("tag:#archive");
  await expect(paraNote).toContainText("no Resource type");
});

test("type list and Books dashboard load from fixtures", async ({ page }) => {
  await gotoPanel(page, "types");

  await expect(harness(page, "type-list")).toBeVisible();
  await expect(harness(page, "type-row").filter({ hasText: "Page" })).toBeVisible();

  const booksList = harness(page, "books-list");
  await expect(booksList).toBeVisible();
  await expect(booksList).toContainText("Atomic Habits");
  await expect(booksList).toContainText("Deep Work");
});

test("collection tabs filter the Books list by vault membership", async ({ page }) => {
  await gotoPanel(page, "types");

  const booksList = harness(page, "books-list");
  await expect(booksList).toContainText("Range");
  await expect(booksList).toContainText("Atomic Habits");

  await harness(page, "collection-tabs").getByRole("button", { name: "Favorites" }).click();

  await expect(booksList).toContainText("Atomic Habits");
  await expect(booksList).toContainText("Deep Work");
  await expect(booksList).not.toContainText("Range");
});

test("collections membership is surfaced as a vault JSON file", async ({ page }) => {
  await gotoPanel(page, "types");

  await expect(harness(page, "collections-list")).toBeVisible();
  await expect(harness(page, "collection-row").filter({ hasText: "Favorites" })).toContainText(
    ".loci/collections/",
  );
  await expect(harness(page, "collections-note")).toHaveAttribute(
    "data-membership-is-vault-file",
    "true",
  );
});

test("pinned query results are visible from the live index", async ({ page }) => {
  await gotoPanel(page, "types");

  const results = harness(page, "queries-results");
  await expect(results).toBeVisible();
  await expect(harness(page, "query-result-row").filter({ hasText: "Deep Work" })).toBeVisible();
  await expect(harness(page, "query-result-row").filter({ hasText: "Range" })).toBeVisible();
});

test("type convert refuses Daily and keeps ObjectID stable", async ({ page }) => {
  await gotoPanel(page, "type-convert");

  await expect(harness(page, "type-convert-proof-refusedDaily")).toHaveText("yes ✓");
  await expect(harness(page, "type-convert-proof-idStable")).toHaveText("yes ✓");
});

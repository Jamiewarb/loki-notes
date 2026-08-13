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

test("object-select picker shows selected title and proof flags", async ({ page }) => {
  await gotoPanel(page, "types");

  await expect(harness(page, "object-select-picker")).toBeVisible();
  await expect(harness(page, "object-select-picker")).toContainText("Cal Newport");
  await expect(harness(page, "object-select-proof-pickerUsesIndexCandidates")).toHaveText(
    "yes ✓",
  );
  await expect(harness(page, "object-select-proof-storesObjectIDs")).toHaveText("yes ✓");
  await expect(harness(page, "object-select-proof-createsRealLinks")).toHaveText("yes ✓");
  await expect(harness(page, "object-select-proof-doesNotRewriteBody")).toHaveText("yes ✓");
  await expect(harness(page, "object-select-proof-indexInsideVault")).toHaveText("NO");
});

test("type dashboard groups filtered books and shows proof flags", async ({ page }) => {
  await gotoPanel(page, "types");

  await expect(harness(page, "dashboard-groups")).toBeVisible();
  await expect(harness(page, "dashboard-section-Reading")).toBeVisible();
  await expect(harness(page, "dashboard-row").filter({ hasText: "Deep Work" })).toBeVisible();
  await expect(harness(page, "dashboard-row").filter({ hasText: "Range" })).toBeVisible();
  await expect(harness(page, "dashboard-proof-filterApplied")).toHaveText("yes ✓");
  await expect(harness(page, "dashboard-proof-sortApplied")).toHaveText("yes ✓");
  await expect(harness(page, "dashboard-proof-groupApplied")).toHaveText("yes ✓");
  await expect(harness(page, "dashboard-proof-resultsNotWrittenToMarkdown")).toHaveText("yes ✓");
  await expect(harness(page, "dashboard-proof-indexInsideVault")).toHaveText("NO");
});

test("type dashboard does not write filter results into markdown", async ({ page }) => {
  await gotoPanel(page, "types");

  await expect(harness(page, "dashboard-note")).toBeVisible();
  await expect(harness(page, "dashboard-note")).toHaveAttribute("data-daily-unchanged", "true");
  await expect(harness(page, "dashboard-note")).toHaveAttribute(
    "data-object-markdown-unchanged",
    "true",
  );
  await expect(harness(page, "dashboard-note")).toHaveAttribute("data-index-inside-vault", "false");
});

test("kanban board columns show moved Deep Work in Done", async ({ page }) => {
  await gotoPanel(page, "types");

  await expect(harness(page, "kanban-board")).toBeVisible();
  await expect(
    harness(page, "kanban-column").filter({ hasText: "To Read" }),
  ).toBeVisible();
  await expect(
    harness(page, "kanban-column").filter({ hasText: "Reading" }),
  ).toBeVisible();
  const done = harness(page, "kanban-column").filter({ hasText: "Done" });
  await expect(done).toBeVisible();
  await expect(done.getByTestId("kanban-card").filter({ hasText: "Deep Work" })).toBeVisible();
  await expect(harness(page, "kanban-proof-boardColumnsFromGroup")).toHaveText("yes ✓");
  await expect(harness(page, "kanban-proof-moveUpdatesVaultYAML")).toHaveText("yes ✓");
  await expect(harness(page, "kanban-proof-layoutNotWrittenToMarkdown")).toHaveText("yes ✓");
  await expect(harness(page, "kanban-proof-indexInsideVault")).toHaveText("NO");
});

test("kanban layout is not written into markdown", async ({ page }) => {
  await gotoPanel(page, "types");

  await expect(harness(page, "kanban-note")).toBeVisible();
  await expect(harness(page, "kanban-note")).toHaveAttribute("data-daily-unchanged", "true");
  await expect(harness(page, "kanban-note")).toHaveAttribute(
    "data-layout-not-written-to-markdown",
    "true",
  );
  await expect(harness(page, "kanban-note")).toHaveAttribute("data-yaml-status-done", "true");
  await expect(harness(page, "kanban-note")).toHaveAttribute("data-index-inside-vault", "false");
});

test("object-select does not rewrite the book body with wiki-links", async ({ page }) => {
  await gotoPanel(page, "types");

  await expect(harness(page, "object-select-note")).toBeVisible();
  await expect(harness(page, "object-select-note")).toHaveAttribute(
    "data-daily-unchanged",
    "true",
  );
  await expect(harness(page, "object-select-note")).toHaveAttribute(
    "data-index-inside-vault",
    "false",
  );
});

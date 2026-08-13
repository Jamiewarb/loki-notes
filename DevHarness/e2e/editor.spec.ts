import { test, expect } from "@playwright/test";
import { gotoPanel, harness } from "./helpers";

test("editor destination loads as an AST HTML preview", async ({ page }) => {
  await gotoPanel(page, "editor");
  await expect(harness(page, "destination")).toHaveAttribute(
    "data-destination",
    "editor",
  );
  await expect(
    page.getByRole("heading", { name: "Editor", exact: true, level: 2 }),
  ).toBeVisible();
  await expect(harness(page, "editor-html")).toBeVisible();
});

test("rich block kinds list tables, toggles, and callouts", async ({ page }) => {
  await gotoPanel(page, "editor");
  const kinds = harness(page, "editor-rich-kinds");
  await expect(kinds).toBeVisible();
  await expect(kinds).toContainText("table");
  await expect(kinds).toContainText("toggle");
  await expect(kinds).toContainText("callout");
});

test("slash simulation list is visible", async ({ page }) => {
  await gotoPanel(page, "editor");
  const slash = harness(page, "editor-slash");
  await expect(slash).toBeVisible();
  await expect(slash).toContainText("h3");
  await expect(slash).toContainText("table");
  await expect(slash).toContainText("toggle");
  await expect(slash).toContainText("callout");
});

test("query embed does not store results in the body", async ({ page }) => {
  await gotoPanel(page, "editor");
  const stores = harness(page, "query-embed-stores");
  await expect(stores).toBeVisible();
  await expect(stores).toHaveText("no");
});

test("block-to-object conversion inserts a wiki-link", async ({ page }) => {
  await gotoPanel(page, "editor");
  const proof = harness(page, "editor-block-to-object");
  await expect(proof).toBeVisible();
  await expect(proof).toContainText("book");
  await expect(proof).toContainText("Deep Work");
  await expect(proof).toContainText("[[");
});

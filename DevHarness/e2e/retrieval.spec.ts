import { expect, test } from "@playwright/test";
import { gotoPanel, harness } from "./helpers";

test("backlinks list is visible on the links panel", async ({ page }) => {
  await gotoPanel(page, "links");
  await expect(harness(page, "backlinks-list")).toBeVisible();
  await expect(harness(page, "backlink-row").filter({ hasText: "Page A" })).toBeVisible();
});

test("graph has nodes from the links index", async ({ page }) => {
  await gotoPanel(page, "graph");
  await expect(harness(page, "graph-node").filter({ hasText: "Deep Work" })).toBeVisible();
});

test("clicking a graph node updates selection text", async ({ page }) => {
  await gotoPanel(page, "graph");
  const node = harness(page, "graph-node").filter({ hasText: "Deep Work" });
  await expect(node).toBeVisible();
  await node.click();
  await expect(harness(page, "graph-selection")).toContainText("Open Deep Work");
  await expect(harness(page, "graph-selection")).toContainText(
    "4dc2795d-2bd7-462a-84ab-c16d50eea5c9",
  );
});

test("graph polish proof flags hide hubs, focus neighbors, and no layout in vault", async ({
  page,
}) => {
  await gotoPanel(page, "graph");
  await expect(harness(page, "graph-proof")).toBeVisible();
  await expect(harness(page, "graph-proof-hidesHighDegree")).toHaveText("yes ✓");
  await expect(harness(page, "graph-proof-focusNeighbors")).toHaveText("yes ✓");
  await expect(harness(page, "graph-proof-layoutNotWrittenToVault")).toHaveText(
    "yes ✓",
  );
  await expect(harness(page, "graph-proof-indexInsideVault")).toHaveText("no ✓");
});

test("hide hubs control drops the high-degree Deep Work node", async ({ page }) => {
  await gotoPanel(page, "graph");
  await expect(harness(page, "graph-node").filter({ hasText: "Deep Work" })).toBeVisible();
  await harness(page, "graph-hide-hubs").click();
  await expect(harness(page, "graph-node").filter({ hasText: "Deep Work" })).toHaveCount(
    0,
  );
  await expect(harness(page, "graph-proof-hidesHighDegree")).toHaveText("yes ✓");
});

test("tag aliases are surfaced on the tags panel", async ({ page }) => {
  await gotoPanel(page, "tags");
  const proof = harness(page, "tags-proof");
  await expect(proof).toBeVisible();
  await expect(proof).toContainText("wellness");
  await expect(proof).toContainText("health");
});

test("search lists FTS hits from the demo fixture", async ({ page }) => {
  await gotoPanel(page, "search");
  await expect(harness(page, "search-proof")).toBeVisible();
  await expect(harness(page, "search-proof")).toContainText("title hit");
  await expect(harness(page, "search-proof")).toContainText("body hit");
  await expect(harness(page, "search-hit").filter({ hasText: "Focus Rituals" })).toBeVisible();
  await expect(harness(page, "search-hit").filter({ hasText: "Deep Work" })).toBeVisible();
});

test("search index is never stored in the vault", async ({ page }) => {
  await gotoPanel(page, "search");
  await expect(harness(page, "search-index-in-vault")).toBeVisible();
  await expect(harness(page, "search-index-in-vault")).toHaveText("no ✓");
});

test("unlinked mentions list includes Notes for Deep Work", async ({ page }) => {
  await gotoPanel(page, "links");
  await expect(harness(page, "unlinked-mentions-panel")).toBeVisible();
  await expect(
    harness(page, "unlinked-mention-row").filter({ hasText: "Notes" }),
  ).toBeVisible();
  await expect(harness(page, "unlinked-proof-detectsPlainTitle")).toHaveText("yes ✓");
  await expect(harness(page, "unlinked-proof-ignoresExistingWikiLink")).toHaveText(
    "yes ✓",
  );
});

test("unlinked mention scan does not rewrite Notes.md until Link", async ({ page }) => {
  await gotoPanel(page, "links");
  await expect(harness(page, "unlinked-notes-body")).toBeVisible();
  await expect(harness(page, "unlinked-notes-body")).toContainText("Deep Work");
  await expect(harness(page, "unlinked-notes-body")).not.toContainText("[[");
  await expect(harness(page, "unlinked-notes-has-wiki")).toHaveText("no");
  await expect(harness(page, "unlinked-proof-doesNotRewriteBody")).toHaveText("yes ✓");
  await expect(harness(page, "unlinked-daily-unchanged")).toHaveText("yes ✓");
  await expect(harness(page, "unlinked-index-in-vault")).toHaveText("no ✓");
});

test("explicit Link replaces the first unlinked title with a wiki-link", async ({
  page,
}) => {
  await gotoPanel(page, "links");
  const link = harness(page, "unlinked-mention-link");
  await expect(link).toBeVisible();
  await link.click();
  await expect(harness(page, "unlinked-notes-body")).toContainText("[[");
  await expect(harness(page, "unlinked-notes-has-wiki")).toHaveText("yes");
});

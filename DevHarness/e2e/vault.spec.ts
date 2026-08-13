import { expect, test } from "@playwright/test";
import { gotoPanel, harness } from "./helpers";

test("markdown round-trip input and serialized panes are visible", async ({
  page,
}) => {
  await gotoPanel(page, "markdown");
  await expect(harness(page, "markdown-input")).toBeVisible();
  await expect(harness(page, "markdown-output")).toBeVisible();
});

test("markdown round-trip is stable", async ({ page }) => {
  await gotoPanel(page, "markdown");
  await expect(harness(page, "markdown-stable")).toBeVisible();
  await expect(harness(page, "markdown-stable")).toHaveText("yes");
});

test("markdown documents are readable files not a database", async ({
  page,
}) => {
  await gotoPanel(page, "markdown");
  const input = harness(page, "markdown-input");
  await expect(input).toBeVisible();
  await expect(input).toContainText("---");
  await expect(input).toContainText("title: Hello Loci");
  await expect(input).toContainText("## Notes");
  await expect(page.getByText(/never store SQLite in the vault/)).toBeVisible();
});

test("import proof flags from demo-import are yes", async ({ page }) => {
  await gotoPanel(page, "import");
  await expect(harness(page, "import-proof")).toBeVisible();

  const flags = [
    "capacitiesBookType",
    "capacitiesDetected",
    "capacitiesPreservedID",
    "capacitiesWrote",
    "conflictSkip",
    "dryRunBeforeApply",
    "indexOutsideVault",
    "markdownDetected",
    "markdownMediaCopied",
    "markdownWrote",
    "obsidianDailyID",
    "obsidianDailyPath",
    "obsidianDetected",
    "obsidianWrote",
  ];
  for (const flag of flags) {
    await expect(harness(page, `import-proof-${flag}`)).toHaveText("yes ✓");
  }
});

test("imported vault paths are .md files not a database", async ({ page }) => {
  await gotoPanel(page, "import");
  await expect(harness(page, "import-daily")).toBeVisible();
  await expect(harness(page, "import-daily")).toContainText(
    /daily\/\d{4}-\d{2}-\d{2}\.md/,
  );
  await expect(page.getByText("objects/page/hello-world.md")).toBeVisible();
  await expect(page.getByText("objects/book/deep-work.md")).toBeVisible();
  await expect(harness(page, "import-proof-indexOutsideVault")).toHaveText(
    "yes ✓",
  );
});

test("settings shows local Documents fallback and index never in the vault", async ({
  page,
}) => {
  await gotoPanel(page, "settings");
  await expect(harness(page, "vault-root-kind")).toBeVisible();
  await expect(harness(page, "vault-root-kind")).toHaveText("localDocuments");
  await expect(page.getByText("local Documents fallback")).toBeVisible();
  await expect(
    page.getByText("Application Support only — never inside the vault"),
  ).toBeVisible();
});

test("settings sync chip and live status load from demo-sync", async ({
  page,
}) => {
  await gotoPanel(page, "settings");
  await expect(harness(page, "sync-chip")).toBeVisible();
  await expect(harness(page, "sync-meta")).toBeVisible();
  await expect(harness(page, "sync-live-status")).toBeVisible();
  await expect(harness(page, "sync-live-status")).not.toHaveText("—");
});

test("settings shows macOS CI shortcut and VoiceOver proofs", async ({
  page,
}) => {
  await gotoPanel(page, "settings");
  await expect(harness(page, "macos-ci-proof")).toBeVisible();
  await expect(harness(page, "macos-ci-proof-macosCIWorkflowPresent")).toHaveText(
    "yes ✓",
  );
  await expect(harness(page, "macos-ci-proof-shortcutsCatalogued")).toHaveText(
    "yes ✓",
  );
  await expect(harness(page, "macos-ci-proof-voiceOverLabelsPresent")).toHaveText(
    "yes ✓",
  );
  await expect(harness(page, "macos-ci-proof-dynamicTypeScales")).toHaveText(
    "yes ✓",
  );
  await expect(harness(page, "macos-ci-proof-indexInsideVault")).toHaveText("NO");
});

import { expect, test } from "@playwright/test";
import { gotoPanel, harness } from "./helpers";

/**
 * Committed demo JSON under public/demo-* that records indexInsideVault.
 * Served by Vite at the same path relative to the site root.
 */
const DEMO_JSON_WITH_INDEX_FLAG = [
  "/demo-ai/ai.json",
  "/demo-apple/apple.json",
  "/demo-calendar/calendar.json",
  "/demo-capture/capture.json",
  "/demo-collections/collections.json",
  "/demo-created-today/created-today.json",
  "/demo-daily/daily.json",
  "/demo-dashboard/dashboard.json",
  "/demo-graph/graph.json",
  "/demo-import/import.json",
  "/demo-index/search.json",
  "/demo-kanban/kanban.json",
  "/demo-links/links.json",
  "/demo-macos-ci/macos-ci.json",
  "/demo-media/media.json",
  "/demo-objects/pages.json",
  "/demo-object-select/object-select.json",
  "/demo-para/para.json",
  "/demo-pins/pins.json",
  "/demo-properties/properties.json",
  "/demo-queries/queries.json",
  "/demo-safari/safari.json",
  "/demo-search/search.json",
  "/demo-tags/tags.json",
  "/demo-tasks/tasks.json",
  "/demo-templates/templates.json",
  "/demo-type-convert/type-convert.json",
  "/demo-weblink-preview/weblink-preview.json",
  "/demo-unlinked-mentions/unlinked-mentions.json",
] as const;

function asRecord(value: unknown): Record<string, unknown> | undefined {
  if (value !== null && typeof value === "object" && !Array.isArray(value)) {
    return value as Record<string, unknown>;
  }
  return undefined;
}

test("demo fixtures never store the index inside the vault", async ({
  request,
}) => {
  for (const url of DEMO_JSON_WITH_INDEX_FLAG) {
    const response = await request.get(url);
    expect.soft(response.ok(), `${url} is served`).toBeTruthy();
    if (!response.ok()) continue;

    const data = asRecord(await response.json());
    expect.soft(data, `${url} is a JSON object`).toBeTruthy();
    if (!data) continue;

    expect.soft(data.indexInsideVault, `${url} indexInsideVault`).toBe(false);

    const proof = asRecord(data.proof);

    if ("dailyUnchanged" in data) {
      expect.soft(data.dailyUnchanged, `${url} dailyUnchanged`).toBe(true);
    }
    if (proof && "dailyUnchanged" in proof) {
      expect.soft(proof.dailyUnchanged, `${url} proof.dailyUnchanged`).toBe(true);
    }
    if ("dailyUnchangedAfterEvents" in data) {
      expect
        .soft(data.dailyUnchangedAfterEvents, `${url} dailyUnchangedAfterEvents`)
        .toBe(true);
    }

    if ("uploadRefusedWithoutOptIn" in data) {
      expect
        .soft(data.uploadRefusedWithoutOptIn, `${url} uploadRefusedWithoutOptIn`)
        .toBe(true);
    }
    if (proof && "uploadRefusedWithoutOptIn" in proof) {
      expect
        .soft(
          proof.uploadRefusedWithoutOptIn,
          `${url} proof.uploadRefusedWithoutOptIn`,
        )
        .toBe(true);
    }

    if ("credentialsInsideVault" in data) {
      expect
        .soft(data.credentialsInsideVault, `${url} credentialsInsideVault`)
        .toBe(false);
    }
    if (proof && "credentialsInsideVault" in proof) {
      expect
        .soft(proof.credentialsInsideVault, `${url} proof.credentialsInsideVault`)
        .toBe(false);
    }
    if ("credentialsOutsideVault" in data) {
      expect
        .soft(data.credentialsOutsideVault, `${url} credentialsOutsideVault`)
        .toBe(true);
    }
    if (proof && "credentialsOutsideVault" in proof) {
      expect
        .soft(
          proof.credentialsOutsideVault,
          `${url} proof.credentialsOutsideVault`,
        )
        .toBe(true);
    }

    if (proof && "photosPickerWired" in proof) {
      expect
        .soft(proof.photosPickerWired, `${url} proof.photosPickerWired`)
        .toBe(true);
    }
    if (proof && "dragDropWired" in proof) {
      expect.soft(proof.dragDropWired, `${url} proof.dragDropWired`).toBe(true);
    }
    if (proof && "eventKitWired" in proof) {
      expect.soft(proof.eventKitWired, `${url} proof.eventKitWired`).toBe(true);
    }
    if (proof && "linuxUsesFakes" in proof) {
      expect.soft(proof.linuxUsesFakes, `${url} proof.linuxUsesFakes`).toBe(true);
    }
    if (proof && "shareExtractsText" in proof) {
      expect
        .soft(proof.shareExtractsText, `${url} proof.shareExtractsText`)
        .toBe(true);
    }
    if (proof && "widgetOpenToday" in proof) {
      expect.soft(proof.widgetOpenToday, `${url} proof.widgetOpenToday`).toBe(true);
    }
    if (proof && "inboxNotIndex" in proof) {
      expect.soft(proof.inboxNotIndex, `${url} proof.inboxNotIndex`).toBe(true);
    }
    if (proof && "menuBarWired" in proof) {
      expect.soft(proof.menuBarWired, `${url} proof.menuBarWired`).toBe(true);
    }
    if (proof && "safariExtractsPage" in proof) {
      expect
        .soft(proof.safariExtractsPage, `${url} proof.safariExtractsPage`)
        .toBe(true);
    }
    if (proof && "macosCIWorkflowPresent" in proof) {
      expect
        .soft(proof.macosCIWorkflowPresent, `${url} proof.macosCIWorkflowPresent`)
        .toBe(true);
    }
    if (proof && "shortcutsCatalogued" in proof) {
      expect
        .soft(proof.shortcutsCatalogued, `${url} proof.shortcutsCatalogued`)
        .toBe(true);
    }
    if (proof && "voiceOverLabelsPresent" in proof) {
      expect
        .soft(proof.voiceOverLabelsPresent, `${url} proof.voiceOverLabelsPresent`)
        .toBe(true);
    }
    if (proof && "dynamicTypeScales" in proof) {
      expect
        .soft(proof.dynamicTypeScales, `${url} proof.dynamicTypeScales`)
        .toBe(true);
    }
    if (proof && "pickerUsesIndexCandidates" in proof) {
      expect
        .soft(
          proof.pickerUsesIndexCandidates,
          `${url} proof.pickerUsesIndexCandidates`,
        )
        .toBe(true);
    }
    if (proof && "storesObjectIDs" in proof) {
      expect.soft(proof.storesObjectIDs, `${url} proof.storesObjectIDs`).toBe(true);
    }
    if (proof && "createsRealLinks" in proof) {
      expect.soft(proof.createsRealLinks, `${url} proof.createsRealLinks`).toBe(true);
    }
    if (proof && "doesNotRewriteBody" in proof) {
      expect
        .soft(proof.doesNotRewriteBody, `${url} proof.doesNotRewriteBody`)
        .toBe(true);
    }
    if (proof && "detectsPlainTitle" in proof) {
      expect
        .soft(proof.detectsPlainTitle, `${url} proof.detectsPlainTitle`)
        .toBe(true);
    }
    if (proof && "ignoresExistingWikiLink" in proof) {
      expect
        .soft(
          proof.ignoresExistingWikiLink,
          `${url} proof.ignoresExistingWikiLink`,
        )
        .toBe(true);
    }
    if (proof && "noteBodyHasAbsolutePath" in proof) {
      expect
        .soft(
          proof.noteBodyHasAbsolutePath,
          `${url} proof.noteBodyHasAbsolutePath`,
        )
        .toBe(false);
    }
  }
});

test("daily panel shows the index is never in the vault", async ({ page }) => {
  await gotoPanel(page, "daily");
  await expect(harness(page, "daily-meta").getByText("Index in vault")).toBeVisible();
  await expect(
    harness(page, "daily-meta").getByText("never", { exact: true }),
  ).toBeVisible();
});

test("ai panel shows upload refused without opt-in", async ({ page }) => {
  await gotoPanel(page, "ai");
  await expect(harness(page, "ai-upload-refused")).toBeVisible();
  await expect(harness(page, "ai-upload-refused")).toHaveText("yes ✓");
});

test("macos-ci demo fixture records workflow, shortcuts, a11y, and no index in vault", async ({
  request,
}) => {
  const response = await request.get("/demo-macos-ci/macos-ci.json");
  expect(response.ok()).toBeTruthy();
  const data = asRecord(await response.json());
  expect(data?.indexInsideVault).toBe(false);
  expect(data?.linuxCannotRunXcodebuild).toBe(true);
  const proof = asRecord(data?.proof);
  expect(proof?.macosCIWorkflowPresent).toBe(true);
  expect(proof?.shortcutsCatalogued).toBe(true);
  expect(proof?.voiceOverLabelsPresent).toBe(true);
  expect(proof?.dynamicTypeScales).toBe(true);
  expect(proof?.indexInsideVault).toBe(false);
});

test("dashboard demo fixture records filter sort group without writing markdown", async ({
  request,
}) => {
  const response = await request.get("/demo-dashboard/dashboard.json");
  expect(response.ok()).toBeTruthy();
  const data = asRecord(await response.json());
  expect(data?.indexInsideVault).toBe(false);
  expect(data?.dailyUnchanged).toBe(true);
  expect(data?.objectMarkdownUnchanged).toBe(true);
  const proof = asRecord(data?.proof);
  expect(proof?.filterApplied).toBe(true);
  expect(proof?.sortApplied).toBe(true);
  expect(proof?.groupApplied).toBe(true);
  expect(proof?.resultsNotWrittenToMarkdown).toBe(true);
  expect(proof?.indexInsideVault).toBe(false);
});

test("kanban demo fixture records board columns and YAML move without writing layout", async ({
  request,
}) => {
  const response = await request.get("/demo-kanban/kanban.json");
  expect(response.ok()).toBeTruthy();
  const data = asRecord(await response.json());
  expect(data?.indexInsideVault).toBe(false);
  expect(data?.dailyUnchanged).toBe(true);
  expect(data?.objectMarkdownUnchanged).toBe(true);
  expect(data?.yamlStatusDone).toBe(true);
  const proof = asRecord(data?.proof);
  expect(proof?.boardColumnsFromGroup).toBe(true);
  expect(proof?.moveUpdatesVaultYAML).toBe(true);
  expect(proof?.layoutNotWrittenToMarkdown).toBe(true);
  expect(proof?.indexInsideVault).toBe(false);
});

test("weblink preview fixture caches OG outside the vault without fetching on type", async ({
  request,
}) => {
  const response = await request.get("/demo-weblink-preview/weblink-preview.json");
  expect(response.ok()).toBeTruthy();
  const data = asRecord(await response.json());
  expect(data?.indexInsideVault).toBe(false);
  expect(data?.cacheInsideVault).toBe(false);
  expect(data?.dailyUnchanged).toBe(true);
  expect(data?.yamlContainsOgTitle).toBe(false);
  expect(data?.previewTitle).toBe("Example Article");
  const proof = asRecord(data?.proof);
  expect(proof?.parsesOpenGraph).toBe(true);
  expect(proof?.cacheOutsideVault).toBe(true);
  expect(proof?.noFetchOnType).toBe(true);
  expect(proof?.indexInsideVault).toBe(false);
});

test("object-select demo fixture stores ObjectIDs and creates real links", async ({
  request,
}) => {
  const response = await request.get("/demo-object-select/object-select.json");
  expect(response.ok()).toBeTruthy();
  const data = asRecord(await response.json());
  expect(data?.indexInsideVault).toBe(false);
  expect(data?.dailyUnchanged).toBe(true);
  expect(data?.bookBodyContainsWikiLink).toBe(false);
  const proof = asRecord(data?.proof);
  expect(proof?.pickerUsesIndexCandidates).toBe(true);
  expect(proof?.storesObjectIDs).toBe(true);
  expect(proof?.createsRealLinks).toBe(true);
  expect(proof?.doesNotRewriteBody).toBe(true);
  expect(proof?.indexInsideVault).toBe(false);
});

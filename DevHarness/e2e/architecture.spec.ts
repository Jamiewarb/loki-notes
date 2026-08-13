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
  "/demo-graph/graph.json",
  "/demo-import/import.json",
  "/demo-index/search.json",
  "/demo-links/links.json",
  "/demo-media/media.json",
  "/demo-objects/pages.json",
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

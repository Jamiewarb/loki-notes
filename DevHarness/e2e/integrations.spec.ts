import { expect, test } from "@playwright/test";
import { gotoPanel, harness } from "./helpers";

test("upload is refused without opt-in", async ({ page }) => {
  await gotoPanel(page, "ai");
  await expect(harness(page, "ai-upload-refused")).toBeVisible();
  await expect(harness(page, "ai-upload-refused")).toHaveText("yes ✓");
  await expect(harness(page, "ai-proof-uploadRefusedWithoutOptIn")).toBeVisible();
  await expect(harness(page, "ai-proof-uploadRefusedWithoutOptIn")).toHaveText("yes ✓");
});

test("credentials live outside the vault", async ({ page }) => {
  await gotoPanel(page, "ai");
  await expect(harness(page, "ai-credentials-in-vault")).toBeVisible();
  await expect(harness(page, "ai-credentials-in-vault")).toHaveText("no ✓");
  await expect(harness(page, "ai-proof-credentialsOutsideVault")).toBeVisible();
  await expect(harness(page, "ai-proof-credentialsOutsideVault")).toHaveText("yes ✓");
});

test("event chrome does not rewrite daily.md", async ({ page }) => {
  await gotoPanel(page, "apple");
  await expect(harness(page, "apple-event").filter({ hasText: "Design review" })).toBeVisible();
  await expect(harness(page, "apple-daily-unchanged")).toBeVisible();
  await expect(harness(page, "apple-daily-unchanged")).toHaveText("yes ✓");
  await expect(harness(page, "apple-proof-dailyUnchanged")).toBeVisible();
  await expect(harness(page, "apple-proof-dailyUnchanged")).toHaveText("yes ✓");
  await expect(harness(page, "apple-daily-body")).toBeVisible();
  await expect(harness(page, "apple-daily-body")).not.toContainText("Design review");
  await expect(harness(page, "apple-proof-eventKitWired")).toBeVisible();
  await expect(harness(page, "apple-proof-eventKitWired")).toHaveText("yes ✓");
  await expect(harness(page, "apple-proof-linuxUsesFakes")).toBeVisible();
  await expect(harness(page, "apple-proof-linuxUsesFakes")).toHaveText("yes ✓");
});

test("meetings are created via ObjectServing", async ({ page }) => {
  await gotoPanel(page, "apple");
  await expect(harness(page, "apple-meeting-path")).toBeVisible();
  await expect(harness(page, "apple-meeting-path")).toContainText("objects/meeting/");
  await expect(harness(page, "apple-proof-meetingPath")).toBeVisible();
  await expect(harness(page, "apple-proof-meetingPath")).toHaveText("yes ✓");
});

test("apple index is never stored in the vault", async ({ page }) => {
  await gotoPanel(page, "apple");
  await expect(harness(page, "apple-index-in-vault")).toBeVisible();
  await expect(harness(page, "apple-index-in-vault")).toHaveText("no ✓");
  await expect(harness(page, "apple-proof-indexOutsideVault")).toBeVisible();
  await expect(harness(page, "apple-proof-indexOutsideVault")).toHaveText("yes ✓");
});

test("safari clipper uses the same Capture inbox", async ({ page }) => {
  await gotoPanel(page, "safari");
  await expect(harness(page, "safari-inbox-empty")).toBeVisible();
  await expect(page.getByText(/\.loci\/inbox/)).toBeVisible();
  await expect(harness(page, "inspector")).toContainText("Same Capture inbox");
});

test("weblink url property is rendered", async ({ page }) => {
  await gotoPanel(page, "safari");
  await expect(harness(page, "safari-weblink-url")).toBeVisible();
  await expect(harness(page, "safari-weblink-url")).toHaveText("https://example.com/weblink");
  await expect(harness(page, "safari-proof-weblinkURLProperty")).toBeVisible();
  await expect(harness(page, "safari-proof-weblinkURLProperty")).toHaveText("yes ✓");
});

test("safari inbox is empty after drain", async ({ page }) => {
  await gotoPanel(page, "safari");
  await expect(harness(page, "safari-inbox-empty")).toBeVisible();
  await expect(harness(page, "safari-inbox-empty")).toHaveText("yes ✓");
  await expect(harness(page, "safari-proof-inboxEmpty")).toBeVisible();
  await expect(harness(page, "safari-proof-inboxEmpty")).toHaveText("yes ✓");
});

test("safari index is never from the extension", async ({ page }) => {
  await gotoPanel(page, "safari");
  await expect(harness(page, "safari-index-in-vault")).toBeVisible();
  await expect(harness(page, "safari-index-in-vault")).toHaveText("no ✓");
  await expect(harness(page, "safari-proof-indexOutsideVault")).toBeVisible();
  await expect(harness(page, "safari-proof-indexOutsideVault")).toHaveText("yes ✓");
  await expect(harness(page, "inspector")).toContainText("index never from extension");
});

import { expect, type Page } from "@playwright/test";

/** All DevHarness panel ids — keep in sync with `src/shell.ts` PanelId. */
export const PANEL_IDS = [
  "daily",
  "tasks",
  "search",
  "types",
  "settings",
  "gallery",
  "markdown",
  "editor",
  "links",
  "tags",
  "media",
  "graph",
  "calendar",
  "capture",
  "import",
  "type-convert",
  "ai",
  "apple",
  "safari",
] as const;

export type PanelId = (typeof PANEL_IDS)[number];

/** Navigate to a panel and wait until the destination has finished replacing its loading tree. */
export async function gotoPanel(page: Page, id: PanelId): Promise<void> {
  await page.goto(`/?panel=${id}`);
  await expectPanelLoaded(page, id);
}

export async function expectPanelLoaded(page: Page, id: PanelId): Promise<void> {
  await expect(page.getByTestId("destination")).toHaveAttribute("data-destination", id);
}

export function harness(page: Page, id: string) {
  return page.getByTestId(id);
}

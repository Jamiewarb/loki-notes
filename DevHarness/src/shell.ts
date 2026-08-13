/**
 * DevHarness shell — mirrors future Loci AppShell (sidebar | detail | inspector).
 *
 * How future PRs add a visual panel:
 * 1. Create `src/panels/<FeatureName>Panel.ts` exporting `{ id, title, render(root) }`.
 * 2. Register it in `PANELS` below.
 * 3. Optionally add a sidebar destination in `NAV_ITEMS`.
 * 4. Document the panel in evidence/<prXX>/ and PREVIOUS_CONTEXT.md.
 */

export type PanelId = "daily" | "search" | "types" | "settings";

export interface NavItem {
  id: PanelId;
  label: string;
}

export interface Panel {
  id: PanelId;
  title: string;
  body: string;
  inspector: string;
}

export const NAV_ITEMS: NavItem[] = [
  { id: "daily", label: "Daily" },
  { id: "search", label: "Search" },
  { id: "types", label: "Types" },
  { id: "settings", label: "Settings" },
];

export const PANELS: Record<PanelId, Panel> = {
  daily: {
    id: "daily",
    title: "Daily",
    body: "Placeholder for today’s note (PR10). Deterministic path daily/YYYY-MM-DD.md.",
    inspector: "Created today and outline panels will land here (PR11).",
  },
  search: {
    id: "search",
    title: "Search",
    body: "Global FTS search placeholder (PR18). Reads IndexQuerying only.",
    inspector: "Recent queries and filters will appear here.",
  },
  types: {
    id: "types",
    title: "Types",
    body: "Object type dashboards placeholder (PR12). Schema lives under .loci/types/.",
    inspector: "Type metadata and property defs (PR13).",
  },
  settings: {
    id: "settings",
    title: "Settings",
    body: "Vault root, local fallback, and sync status (PR04 / PR21).",
    inspector: "iCloud vs local Documents — index never stored in the vault.",
  },
};

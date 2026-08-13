/**
 * DevHarness shell — mirrors Loci AppShell (sidebar | detail | inspector).
 *
 * How future PRs add a visual panel:
 * 1. Create `src/panels/<FeatureName>Panel.ts` exporting a render(root) function.
 * 2. Register it in `PANELS` below (and optionally `NAV_ITEMS`).
 * 3. Document the panel in evidence/<prXX>/ and PREVIOUS_CONTEXT.md.
 */

export type PanelId = "daily" | "search" | "types" | "settings" | "gallery" | "markdown";

export interface NavItem {
  id: PanelId;
  label: string;
  subtitle: string;
  section: "primary" | "pinned" | "studio";
}

export interface Panel {
  id: PanelId;
  title: string;
  body: string;
  inspector: string;
  /** When set, main.ts calls this instead of the generic placeholder body. */
  render?: (root: HTMLElement) => void;
}

/** Primary destinations — matches AppRoute.primary / Route.primaryDestinations. */
export const PRIMARY_NAV: NavItem[] = [
  { id: "daily", label: "Daily", subtitle: "Today’s note", section: "primary" },
  { id: "search", label: "Search", subtitle: "Full-text index", section: "primary" },
  { id: "types", label: "Types", subtitle: "Object dashboards", section: "primary" },
  { id: "settings", label: "Settings", subtitle: "Vault & sync", section: "primary" },
];

/** Pin section stub — real pins arrive with Object CRUD. */
export const PINNED_STUB = {
  id: "pin-inbox",
  label: "Inbox",
  subtitle: "Pinned · coming later",
} as const;

/** Tooling / debug destinations (Design gallery + Markdown kit). */
export const STUDIO_NAV: NavItem[] = [
  { id: "gallery", label: "Design", subtitle: "Tokens & primitives", section: "studio" },
  { id: "markdown", label: "Markdown", subtitle: "AST round-trip", section: "studio" },
];

/** Flat list for click wiring (primary + studio). */
export const NAV_ITEMS: NavItem[] = [...PRIMARY_NAV, ...STUDIO_NAV];

export const PANELS: Record<PanelId, Panel> = {
  daily: {
    id: "daily",
    title: "Daily",
    body: "Today’s note opens here (PR10). Deterministic path daily/YYYY-MM-DD.md.",
    inspector: "Created today and outline panels will land here (PR11).",
  },
  search: {
    id: "search",
    title: "Search",
    body: "Local index FTS demo (PR07). Reads IndexQuerying only — never blocks typing. Full ⌘K UI lands in PR18.",
    inspector: "Index lives in Application Support — never inside the vault.",
  },
  types: {
    id: "types",
    title: "Types",
    body: "Object type list (PR05). Built-in Page under .loci/types/page.json — merge-friendly per-type schema.",
    inspector: "Type metadata from SchemaStore; property editors arrive in PR13.",
  },
  settings: {
    id: "settings",
    title: "Settings",
    body: "Vault root, local Documents fallback, and sync status (PR04). Create vault writes .loci/space.json.",
    inspector: "iCloud vs local Documents — index never stored in the vault.",
  },
  gallery: {
    id: "gallery",
    title: "Design gallery",
    body: "Tokens + primitives mirrored from LociDesignSystem (PR02).",
    inspector: "editorial-sage · Fraunces + Source Sans 3 · moss-teal accent.",
  },
  markdown: {
    id: "markdown",
    title: "Markdown",
    body: "Loci MD ↔ BlockAST debug round-trip (PR06). Frontmatter aligns with LociObjectMeta.",
    inspector: "Wiki-links and #tags feed the Indexer (PR07).",
  },
};

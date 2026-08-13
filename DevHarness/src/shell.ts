/**
 * DevHarness shell — mirrors Loci AppShell (sidebar | detail | inspector).
 *
 * How future PRs add a visual panel:
 * 1. Create `src/panels/<FeatureName>Panel.ts` exporting a render(root) function.
 * 2. Register it in `PANELS` below (and optionally `NAV_ITEMS`).
 * 3. Document the panel in evidence/<prXX>/ and PREVIOUS_CONTEXT.md.
 */

export type PanelId =
  | "daily"
  | "tasks"
  | "search"
  | "types"
  | "settings"
  | "gallery"
  | "markdown"
  | "editor"
  | "links"
  | "tags"
  | "media"
  | "graph"
  | "calendar"
  | "capture";

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
  { id: "tasks", label: "Tasks", subtitle: "Today & open", section: "primary" },
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

/** Tooling / debug destinations (Design gallery + Markdown kit + Editor). */
export const STUDIO_NAV: NavItem[] = [
  { id: "gallery", label: "Design", subtitle: "Tokens & primitives", section: "studio" },
  { id: "markdown", label: "Markdown", subtitle: "AST round-trip", section: "studio" },
  { id: "editor", label: "Editor", subtitle: "Block session + slash", section: "studio" },
  { id: "links", label: "Links", subtitle: "Wiki-links + backlinks", section: "studio" },
  { id: "graph", label: "Graph", subtitle: "Wiki-link network", section: "studio" },
  { id: "calendar", label: "Calendar", subtitle: "Daily notes · dots", section: "studio" },
  { id: "capture", label: "Capture", subtitle: "Share · widget · menu bar", section: "studio" },
  { id: "tags", label: "Tags", subtitle: "Cross-type #tags", section: "studio" },
  { id: "media", label: "Media", subtitle: "Attach + image objects", section: "studio" },
];

/** Flat list for click wiring (primary + studio). */
export const NAV_ITEMS: NavItem[] = [...PRIMARY_NAV, ...STUDIO_NAV];

export const PANELS: Record<PanelId, Panel> = {
  daily: {
    id: "daily",
    title: "Daily",
    body: "Today’s note — daily/YYYY-MM-DD.md + id daily-YYYY-MM-DD (PR10).",
    inspector: "Created today + open tasks — IndexQuerying; daily .md never rewritten on create.",
  },
  tasks: {
    id: "tasks",
    title: "Tasks",
    body: "Today / Open tasks (PR19). Index tasks table · toggles persist via ObjectServing.save · never block typing.",
    inspector: "Aggregation only — checkboxes write vault markdown then reindex.",
  },
  search: {
    id: "search",
    title: "Search",
    body: "Global FTS (PR18). ⌘K / SearchView · IndexQuerying.search · results grouped by type · never blocks typing.",
    inspector: "Recent queries · type filters · index in Application Support only.",
  },
  types: {
    id: "types",
    title: "Types",
    body: "Custom types + property defs + collection tabs (PR12/PR13/PR22). Manual collections under .loci/collections/<type>.<slug>.json.",
    inspector: "Property defs · templates · collection membership (vault JSON, not index).",
  },
  settings: {
    id: "settings",
    title: "Settings",
    body: "Vault root + Sync UX (PR21) + PARA pack (PR15). Sync chip, conflicts (incl. media), rebuild index, reveal vault path.",
    inspector: "iCloud vs local Documents — index never stored in the vault. Sync status + conflict list.",
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
  editor: {
    id: "editor",
    title: "Editor",
    body: "EditorSession BlockAST + slash insert simulation (PR09). HTML preview of tasks/headings/lists.",
    inspector: "Autosave debounced to ObjectServing; index never on keystroke.",
  },
  links: {
    id: "links",
    title: "Links",
    body: "Wiki-links [[id|title]] + @ picker (PR16). LinkResolver prefers ObjectID; backlinks from links table.",
    inspector: "Backlinks panel · broken-link styling (is-broken) · index never in vault.",
  },
  graph: {
    id: "graph",
    title: "Graph",
    body: "Force-directed link graph (PR24). IndexQuerying.graph from links table · type filter · node/edge caps · open on tap.",
    inspector: "Caps · Navigating.open · index never in vault.",
  },
  calendar: {
    id: "calendar",
    title: "Calendar",
    body: "Month/week calendar (PR25). Anchored to daily/YYYY-MM-DD.md · index dots for content/creations · jump via DailyNoteServing.ensure.",
    inspector: "Dots from IndexQuerying.calendarMarkers · never rewrite vault for chrome.",
  },
  capture: {
    id: "capture",
    title: "Capture",
    body: "Share / widget / menu bar (PR26). Extensions enqueue .loci/inbox/*.json; main app drains → today or typed object. Index on foreground only.",
    inspector: "Staging inbox is transient — daily remains the user-facing inbox.",
  },
  tags: {
    id: "tags",
    title: "Tags",
    body: "Object-level + body #tags (PR17). Tag browse is cross-type; aliases in space.json; dashboard filter.",
    inspector: "Object tags editor · aliases · index never in vault.",
  },
  media: {
    id: "media",
    title: "Media",
    body: "Attach image/file → media/ (PR20). Markdown ![alt](…) · Image object type · blobs never in SQLite.",
    inspector: "media/images + media/files listing · Image object media-path property.",
  },
};

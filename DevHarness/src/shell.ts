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
  | "capture"
  | "import"
  | "type-convert"
  | "ai"
  | "apple"
  | "safari";

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

/** Pins load from `/demo-pins/pins.json` (PR34) — not a stub destination. */

/** Tooling / debug destinations (Design gallery + Markdown kit + Editor). */
export const STUDIO_NAV: NavItem[] = [
  { id: "gallery", label: "Design", subtitle: "Tokens & primitives", section: "studio" },
  { id: "markdown", label: "Markdown", subtitle: "AST round-trip", section: "studio" },
  { id: "editor", label: "Editor", subtitle: "Block session + slash", section: "studio" },
  { id: "links", label: "Links", subtitle: "Wiki-links + backlinks", section: "studio" },
  { id: "graph", label: "Graph", subtitle: "Wiki-link network", section: "studio" },
  { id: "calendar", label: "Calendar", subtitle: "Daily notes · dots", section: "studio" },
  { id: "capture", label: "Capture", subtitle: "Share · widget · menu bar", section: "studio" },
  { id: "import", label: "Import", subtitle: "Markdown · Obsidian · Capacities", section: "studio" },
  {
    id: "type-convert",
    label: "Convert",
    subtitle: "Type · property map",
    section: "studio",
  },
  { id: "ai", label: "AI", subtitle: "Assist · BYOK", section: "studio" },
  { id: "apple", label: "Apple", subtitle: "Calendar · Reminders", section: "studio" },
  { id: "safari", label: "Safari", subtitle: "Clip · Weblink", section: "studio" },
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
  import: {
    id: "import",
    title: "Import",
    body: "Import (PR27). Markdown folder · Obsidian vault · Capacities export — dry-run summary then apply into objects/daily/media. Preserve ObjectID + daily paths when detectable.",
    inspector: "ImportServing only — no parallel store; index stays outside the vault.",
  },
  "type-convert": {
    id: "type-convert",
    title: "Convert",
    body: "Type conversion (PR28). Property mapping UI · move objects/<type>/ · ObjectID stable · index via ObjectServing / IndexUpdating.",
    inspector: "Map PropertyDefs · refuse daily · index never in vault.",
  },
  ai: {
    id: "ai",
    title: "AI",
    body: "AI assist (PR30). Summarize · rewrite · translate · property autofill. On-device heuristics / BYOK with explicit upload opt-in. Apply via ObjectServing only.",
    inspector: "Credentials in Application Support · never vault · never upload without opt-in.",
  },
  apple: {
    id: "apple",
    title: "Apple",
    body: "Apple Calendar / Reminders (PR31). Event list on daily is chrome · Create Meeting → objects/meeting/ · optional Reminders sync (explicit).",
    inspector: "Settings in Application Support · daily .md unchanged by event list · index never in vault.",
  },
  safari: {
    id: "safari",
    title: "Safari",
    body: "Safari web clipper (PR38). Extension JS payload url/title/selection → .loci/inbox/*.json · drain → today (`· safari`) or Weblink. Menu bar install() + loci://daily/today.",
    inspector: "Same Capture inbox · Weblink preview cache (Application Support) · index never from extension.",
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

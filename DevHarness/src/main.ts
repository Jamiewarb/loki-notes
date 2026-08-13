import "./styles.css";
import {
  NAV_ITEMS,
  PANELS,
  PINNED_STUB,
  PRIMARY_NAV,
  STUDIO_NAV,
  type PanelId,
} from "./shell";
import { renderDesignGallery } from "./panels/DesignGalleryPanel";
import { renderDailyPanel } from "./panels/DailyPanel";
import { renderDestinationPlaceholder } from "./panels/DestinationPanel";
import { renderEditorPanel } from "./panels/EditorPanel";
import { renderLinksPanel } from "./panels/LinksPanel";
import { renderTagsPanel } from "./panels/TagsPanel";
import { renderMarkdownDebug } from "./panels/MarkdownDebugPanel";
import { renderSearchIndex } from "./panels/SearchIndexPanel";
import { renderSettingsVault } from "./panels/SettingsVaultPanel";
import { renderTypesSchema } from "./panels/TypesSchemaPanel";
import { renderTasksPanel } from "./panels/TasksPanel";
import { renderMediaPanel } from "./panels/MediaPanel";
import { renderGraphPanel } from "./panels/GraphPanel";
import { renderCalendarPanel } from "./panels/CalendarPanel";

const app = document.querySelector<HTMLDivElement>("#app");
if (!app) {
  throw new Error("#app missing");
}

function panelFromQuery(): PanelId {
  const params = new URLSearchParams(window.location.search);
  const raw = params.get("panel");
  if (raw && raw in PANELS) return raw as PanelId;
  return "daily";
}

/** Default to Daily — primary shell destination (matches AppServices). */
let active: PanelId = panelFromQuery();

const DESTINATION_ICONS: Record<PanelId, string> = {
  daily: "☀",
  tasks: "☑",
  search: "⌕",
  types: "▦",
  settings: "⚙",
  gallery: "◈",
  markdown: "¶",
  editor: "✎",
  links: "⇉",
  tags: "#",
  media: "▣",
  graph: "⬡",
  calendar: "▦",
};

function renderNavSection(
  label: string,
  items: { id: string; label: string; subtitle: string }[],
  options?: { stub?: boolean },
): string {
  const buttons = items
    .map((item) => {
      const isActive = !options?.stub && item.id === active;
      return `
        <button
          type="button"
          class="nav-btn${options?.stub ? " is-stub" : ""}"
          data-nav="${item.id}"
          aria-current="${isActive ? "page" : "false"}"
          ${options?.stub ? "disabled" : ""}
        >
          <span class="nav-btn-label">${item.label}</span>
          <span class="nav-btn-sub">${item.subtitle}</span>
        </button>
      `;
    })
    .join("");

  return `
    <div class="nav-section">
      <p class="nav-section-label">${label}</p>
      <nav class="nav" aria-label="${label}">${buttons}</nav>
    </div>
  `;
}

function renderDetail(panelId: PanelId, detail: HTMLElement): void {
  const panel = PANELS[panelId];
  if (panelId === "gallery") {
    renderDesignGallery(detail);
    return;
  }
  if (panelId === "daily") {
    void renderDailyPanel(detail);
    return;
  }
  if (panelId === "settings") {
    renderSettingsVault(detail);
    return;
  }
  if (panelId === "types") {
    void renderTypesSchema(detail);
    return;
  }
  if (panelId === "markdown") {
    void renderMarkdownDebug(detail);
    return;
  }
  if (panelId === "editor") {
    void renderEditorPanel(detail);
    return;
  }
  if (panelId === "links") {
    void renderLinksPanel(detail);
    return;
  }
  if (panelId === "tags") {
    void renderTagsPanel(detail);
    return;
  }
  if (panelId === "search") {
    void renderSearchIndex(detail);
    return;
  }
  if (panelId === "tasks") {
    void renderTasksPanel(detail);
    return;
  }
  if (panelId === "media") {
    void renderMediaPanel(detail);
    return;
  }
  if (panelId === "graph") {
    void renderGraphPanel(detail);
    return;
  }
  if (panelId === "calendar") {
    void renderCalendarPanel(detail);
    return;
  }
  renderDestinationPlaceholder(detail, {
    id: panelId,
    title: panel.title,
    message: panel.body,
    iconHint: DESTINATION_ICONS[panelId],
  });
}

function render(): void {
  const panel = PANELS[active];
  app.innerHTML = `
    <div class="shell" data-harness="loci-shell" data-active="${active}">
      <header class="brand-bar">
        <h1 class="brand">Loci</h1>
        <p class="brand-tag">App shell — sidebar · detail · inspector. Vault is truth; index is local.</p>
      </header>
      <aside class="sidebar" aria-label="Primary" data-harness="sidebar">
        ${renderNavSection("Navigate", PRIMARY_NAV)}
        ${renderNavSection("Pinned", [
          {
            id: PINNED_STUB.id,
            label: PINNED_STUB.label,
            subtitle: PINNED_STUB.subtitle,
          },
        ], { stub: true })}
        ${renderNavSection("Studio", STUDIO_NAV)}
        <p class="harness-note">Add panels in <code>src/panels/</code> and register in <code>shell.ts</code>.</p>
      </aside>
      <main class="detail" data-panel="${panel.id}" data-harness="detail">
        <div data-detail-root></div>
      </main>
      <aside class="inspector" aria-label="Inspector" data-harness="inspector">
        <h3>Inspector</h3>
        <p class="inspector-title">${inspectorTitle(active)}</p>
        <div data-inspector-root>
          <p>${panel.inspector}</p>
        </div>
        <p class="inspector-hint">macOS: trailing split · iOS: sheet / secondary stack</p>
      </aside>
    </div>
  `;

  const detail = app.querySelector<HTMLElement>("[data-detail-root]");
  if (!detail) return;

  renderDetail(active, detail);

  const inspectorRoot = app.querySelector<HTMLElement>("[data-inspector-root]");
  if (inspectorRoot && active === "daily") {
    void renderCreatedTodayInspector(inspectorRoot);
  }
  if (inspectorRoot && active === "tasks") {
    void renderTasksInspector(inspectorRoot);
  }
  if (inspectorRoot && active === "types") {
    void renderPropertiesInspector(inspectorRoot);
  }
  if (inspectorRoot && active === "links") {
    void renderBacklinksInspector(inspectorRoot);
  }
  if (inspectorRoot && active === "tags") {
    void renderTagsInspector(inspectorRoot);
  }
  if (inspectorRoot && active === "media") {
    void renderMediaInspector(inspectorRoot);
  }

  app.querySelectorAll<HTMLButtonElement>("[data-nav]:not(:disabled)").forEach((btn) => {
    btn.addEventListener("click", () => {
      const id = btn.dataset.nav as PanelId;
      if (id && NAV_ITEMS.some((n) => n.id === id) && id !== active) {
        active = id;
        render();
      }
    });
  });
}

/** Daily inspector: live Created today links from demo-created-today fixture (PR11). */
async function renderCreatedTodayInspector(root: HTMLElement): Promise<void> {
  root.innerHTML = `<p data-harness="inspector-created-loading">Loading created today…</p>`;
  try {
    const [createdRes, tasksRes] = await Promise.all([
      fetch("/demo-created-today/created-today.json", { cache: "no-store" }),
      fetch("/demo-tasks/tasks.json", { cache: "no-store" }),
    ]);
    if (!createdRes.ok) throw new Error(`HTTP ${createdRes.status}`);
    const data = (await createdRes.json()) as {
      createdToday?: Array<{
        id: string;
        type: string;
        title: string;
        relativePath: string;
      }>;
      proof?: { dailyUnchanged?: boolean };
      note?: string;
    };
    const items = data.createdToday ?? [];
    const rows = items
      .map(
        (h) => `
        <li class="schema-type-row" data-harness="inspector-created-row" data-object-id="${escapeAttr(
          h.id,
        )}" role="button" tabindex="0">
          <span class="schema-type-name">${escapeAttr(h.title)}</span>
          <span class="schema-type-meta">${escapeAttr(h.type)}</span>
        </li>`,
      )
      .join("");

    let openTasksHtml = "";
    if (tasksRes.ok) {
      const tasksData = (await tasksRes.json()) as {
        openTasks?: Array<{ text: string; completed: boolean }>;
        todayTasks?: Array<{ text: string; completed: boolean }>;
      };
      const openOnDaily = (tasksData.todayTasks ?? []).filter((t) => !t.completed);
      openTasksHtml = `
        <p class="vault-kicker" style="margin-top:0.75rem">Open tasks (today)</p>
        <ul class="schema-type-list" data-harness="inspector-open-tasks">
          ${
            openOnDaily
              .map(
                (t) =>
                  `<li class="schema-type-row"><span class="schema-type-name">☐ ${escapeAttr(
                    t.text,
                  )}</span></li>`,
              )
              .join("") || "<li class='schema-type-row'>None</li>"
          }
        </ul>`;
    }

    root.innerHTML = `
      <p>Index-only · daily.md ${data.proof?.dailyUnchanged ? "unchanged ✓" : "?"} after create.</p>
      <ul class="schema-type-list" data-harness="inspector-created-list" style="margin-top:0.75rem">
        ${rows || "<li class='schema-type-row'>Empty</li>"}
      </ul>
      ${openTasksHtml}
      <p class="inspector-hint" style="margin-top:0.75rem">${escapeAttr(
        data.note ?? "Tap a row — Navigating.open in the app.",
      )}</p>
      <div class="page-detail" data-harness="inspector-created-detail" hidden style="margin-top:0.75rem">
        <p class="vault-card-body" data-harness="inspector-created-detail-body"></p>
      </div>
    `;
    const detail = root.querySelector<HTMLElement>("[data-harness='inspector-created-detail']");
    const detailBody = root.querySelector<HTMLElement>(
      "[data-harness='inspector-created-detail-body']",
    );
    root.querySelectorAll<HTMLLIElement>("[data-harness='inspector-created-row']").forEach((row) => {
      const show = () => {
        const id = row.dataset.objectId ?? "";
        const hit = items.find((h) => h.id === id);
        if (!detail || !detailBody) return;
        detail.hidden = false;
        detailBody.textContent = hit
          ? `Open ${hit.title} → ${hit.relativePath}`
          : "Unknown";
      };
      row.addEventListener("click", show);
      row.addEventListener("keydown", (ev) => {
        if (ev.key === "Enter" || ev.key === " ") {
          ev.preventDefault();
          show();
        }
      });
    });
  } catch {
    root.innerHTML = `<p>Missing created-today fixture. Run <code>./scripts/demo-created-today.sh</code>.</p>`;
  }
}

/** Tasks inspector: proof summary from demo-tasks fixture (PR19). */
async function renderTasksInspector(root: HTMLElement): Promise<void> {
  root.innerHTML = `<p data-harness="inspector-tasks-loading">Loading tasks…</p>`;
  try {
    const res = await fetch("/demo-tasks/tasks.json", { cache: "no-store" });
    if (!res.ok) throw new Error(`HTTP ${res.status}`);
    const data = (await res.json()) as {
      proof?: {
        pageToggleCompleted?: boolean;
        dailyHasOpen?: boolean;
        openCount?: number;
        todayCount?: number;
      };
      note?: string;
    };
    const proof = data.proof ?? {};
    root.innerHTML = `
      <p>Today / Open · index projection.</p>
      <ul class="schema-type-list" style="margin-top:0.75rem" data-harness="inspector-tasks-proof">
        <li class="schema-type-row"><span class="schema-type-name">Page toggle completed</span><span class="schema-type-meta">${
          proof.pageToggleCompleted ? "✓" : "?"
        }</span></li>
        <li class="schema-type-row"><span class="schema-type-name">Today count</span><span class="schema-type-meta">${
          proof.todayCount ?? 0
        }</span></li>
        <li class="schema-type-row"><span class="schema-type-name">Open count</span><span class="schema-type-meta">${
          proof.openCount ?? 0
        }</span></li>
      </ul>
      <p class="inspector-hint" style="margin-top:0.75rem">${escapeAttr(
        data.note ?? "Checkboxes write vault markdown via ObjectServing.save.",
      )}</p>
    `;
  } catch {
    root.innerHTML = `<p>Missing tasks fixture. Run <code>./scripts/demo-tasks.sh</code>.</p>`;
  }
}

/** Types inspector: Book templates + property values (PR14). */
async function renderPropertiesInspector(root: HTMLElement): Promise<void> {
  root.innerHTML = `<p data-harness="inspector-props-loading">Loading templates…</p>`;
  try {
    const res = await fetch("/demo-templates/templates.json", { cache: "no-store" });
    if (!res.ok) {
      // Fall back to properties fixture if templates not generated yet.
      const propsRes = await fetch("/demo-properties/properties.json", { cache: "no-store" });
      if (!propsRes.ok) throw new Error(`HTTP ${res.status}`);
      await renderLegacyPropertiesInspector(root, await propsRes.json());
      return;
    }
    const data = (await res.json()) as {
      bookTemplate?: { id?: string; name?: string };
      dailyTemplate?: { id?: string; name?: string };
      bookObject?: {
        title?: string;
        properties?: Record<string, string | number | boolean>;
        bodyMarkdown?: string;
      };
      dailyObject?: { bodyMarkdown?: string };
      bookPrefill?: boolean;
      dailyPrefill?: boolean;
      bookType?: {
        properties?: Array<{ id?: string; name?: string; kind?: string }>;
        defaultTemplateID?: string;
      };
    };
    const defs = data.bookType?.properties ?? [];
    const values = data.bookObject?.properties ?? {};
    const defRows = defs
      .map(
        (d) =>
          `<li class="schema-type-row"><span class="schema-type-name">${escapeAttr(
            d.name ?? d.id ?? "?",
          )}</span><span class="schema-type-meta">${escapeAttr(
            d.kind ?? "",
          )}</span></li>`,
      )
      .join("");
    const valueRows = Object.entries(values)
      .map(
        ([k, v]) =>
          `<li class="schema-type-row" data-harness="inspector-prop-value" data-key="${escapeAttr(
            k,
          )}"><span class="schema-type-name">${escapeAttr(
            k,
          )}</span><span class="schema-type-meta">${escapeAttr(String(v))}</span></li>`,
      )
      .join("");
    root.innerHTML = `
      <p>Templates · book ${data.bookPrefill ? "✓" : "?"} · daily ${
        data.dailyPrefill ? "✓" : "?"
      }</p>
      <p class="vault-kicker" style="margin-top:0.75rem">Defaults</p>
      <ul class="schema-type-list" data-harness="inspector-templates">
        <li class="schema-type-row"><span class="schema-type-name">${escapeAttr(
          data.bookTemplate?.name ?? "Book",
        )}</span><span class="schema-type-meta">${escapeAttr(
          data.bookTemplate?.id ?? "?",
        )}</span></li>
        <li class="schema-type-row"><span class="schema-type-name">${escapeAttr(
          data.dailyTemplate?.name ?? "Daily",
        )}</span><span class="schema-type-meta">${escapeAttr(
          data.dailyTemplate?.id ?? "?",
        )}</span></li>
      </ul>
      <p class="vault-kicker" style="margin-top:0.75rem">Defs</p>
      <ul class="schema-type-list" data-harness="inspector-prop-defs">${
        defRows || "<li>none</li>"
      }</ul>
      <p class="vault-kicker" style="margin-top:0.75rem">${escapeAttr(
        data.bookObject?.title ?? "Object",
      )}</p>
      <ul class="schema-type-list" data-harness="inspector-prop-values">${
        valueRows || "<li>none</li>"
      }</ul>
    `;
  } catch {
    root.innerHTML = `<p>Missing templates fixture. Run <code>./scripts/demo-templates.sh</code>.</p>`;
  }
}

async function renderLegacyPropertiesInspector(root: HTMLElement, data: unknown): Promise<void> {
  const d = data as {
    bookType?: {
      properties?: Array<{ id?: string; name?: string; kind?: string }>;
    };
    object?: {
      title?: string;
      properties?: Record<string, string | number | boolean>;
    };
    survivedReload?: boolean;
    statusIndexed?: boolean;
    ratingIndexed?: boolean;
  };
  const defs = d.bookType?.properties ?? [];
  const values = d.object?.properties ?? {};
  const defRows = defs
    .map(
      (x) =>
        `<li class="schema-type-row"><span class="schema-type-name">${escapeAttr(
          x.name ?? x.id ?? "?",
        )}</span><span class="schema-type-meta">${escapeAttr(x.kind ?? "")}</span></li>`,
    )
    .join("");
  const valueRows = Object.entries(values)
    .map(
      ([k, v]) =>
        `<li class="schema-type-row"><span class="schema-type-name">${escapeAttr(
          k,
        )}</span><span class="schema-type-meta">${escapeAttr(String(v))}</span></li>`,
    )
    .join("");
  root.innerHTML = `
    <p>Book defs → object values (YAML). Reload ${d.survivedReload ? "✓" : "?"}</p>
    <ul class="schema-type-list">${defRows || "<li>none</li>"}</ul>
    <ul class="schema-type-list">${valueRows || "<li>none</li>"}</ul>
  `;
}

function escapeAttr(value: string): string {
  return value
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;");
}

function inspectorTitle(id: PanelId): string {
  switch (id) {
    case "daily":
      return "Created today · Open tasks";
    case "tasks":
      return "Aggregation";
    case "search":
      return "Filters";
    case "types":
      return "Templates · property defs";
    case "settings":
      return "PARA · sync status · conflicts";
    case "gallery":
      return "Tokens";
    case "markdown":
      return "BlockAST";
    case "editor":
      return "Slash · keymap";
    case "links":
      return "Backlinks";
    case "graph":
      return "Caps · Navigating";
    case "calendar":
      return "Dots · daily jump";
    case "tags":
      return "Object tags · aliases";
    case "media":
      return "media/ listing";
  }
}

/** Links inspector: backlinks on Page B from demo-links fixture (PR16). */
async function renderBacklinksInspector(root: HTMLElement): Promise<void> {
  root.innerHTML = `<p data-harness="inspector-links-loading">Loading backlinks…</p>`;
  try {
    const res = await fetch("/demo-links/links.json", { cache: "no-store" });
    if (!res.ok) throw new Error(`HTTP ${res.status}`);
    const data = (await res.json()) as {
      pageB?: { title?: string };
      backlinksOnB?: Array<{ sourceId: string; sourceTitle: string; target: string }>;
      outgoingFromA?: Array<{ isBroken: boolean; styleClass: string; label?: string; target: string }>;
      note?: string;
    };
    const backs = data.backlinksOnB ?? [];
    const rows = backs
      .map(
        (b) => `
        <li class="schema-type-row" data-harness="inspector-backlink-row">
          <span class="schema-type-name">${escapeAttr(b.sourceTitle)}</span>
          <span class="schema-type-meta">[[${escapeAttr(b.target)}]]</span>
        </li>`,
      )
      .join("");
    const outgoing = (data.outgoingFromA ?? [])
      .map(
        (l) => `
        <li class="schema-type-row">
          <span class="${escapeAttr(l.styleClass)}">${escapeAttr(l.label || l.target)}</span>
          <span class="schema-type-meta">${l.isBroken ? "broken" : "ok"}</span>
        </li>`,
      )
      .join("");
    root.innerHTML = `
      <p>Backlinks on <strong>${escapeAttr(data.pageB?.title ?? "B")}</strong> · index-only.</p>
      <ul class="schema-type-list" data-harness="inspector-backlinks-list" style="margin-top:0.75rem">
        ${rows || "<li class='schema-type-row'>Empty</li>"}
      </ul>
      <p class="vault-kicker" style="margin-top:0.75rem">Outgoing</p>
      <ul class="schema-type-list" data-harness="inspector-outgoing-list">${
        outgoing || "<li>none</li>"
      }</ul>
      <p class="inspector-hint" style="margin-top:0.75rem">${escapeAttr(
        data.note ?? "Tap navigates via Navigating.open in the app.",
      )}</p>
    `;
  } catch {
    root.innerHTML = `<p>Missing links fixture. Run <code>./scripts/demo-links.sh</code>.</p>`;
  }
}

/** Tags inspector: object-level tags + aliases from demo-tags fixture (PR17). */
async function renderTagsInspector(root: HTMLElement): Promise<void> {
  root.innerHTML = `<p data-harness="inspector-tags-loading">Loading tags…</p>`;
  try {
    const res = await fetch("/demo-tags/tags.json", { cache: "no-store" });
    if (!res.ok) throw new Error(`HTTP ${res.status}`);
    const data = (await res.json()) as {
      page?: { title?: string; tags?: string[] };
      aliases?: Record<string, string[]>;
      note?: string;
    };
    const tags = (data.page?.tags ?? []).map((t) => `#${t}`).join(" ") || "(none)";
    const aliasBits = Object.entries(data.aliases ?? {})
      .map(([k, v]) => `${k} ← ${(v || []).join(", ")}`)
      .join(" · ");
    root.innerHTML = `
      <p>Object tags on <strong>${escapeAttr(data.page?.title ?? "Page")}</strong> (frontmatter).</p>
      <p class="vault-card-body" data-harness="inspector-object-tags" style="margin-top:0.75rem">${escapeAttr(tags)}</p>
      <p class="vault-kicker" style="margin-top:0.75rem">Aliases (space.json)</p>
      <p class="vault-card-body" data-harness="inspector-tag-aliases">${escapeAttr(aliasBits || "(none)")}</p>
      <p class="inspector-hint" style="margin-top:0.75rem">${escapeAttr(
        data.note ?? "Do not auto-write derived tag lists into markdown.",
      )}</p>
    `;
  } catch {
    root.innerHTML = `<p>Missing tags fixture. Run <code>./scripts/demo-tags.sh</code>.</p>`;
  }
}

/** Media inspector: proof from demo-media fixture (PR20). */
async function renderMediaInspector(root: HTMLElement): Promise<void> {
  root.innerHTML = `<p data-harness="inspector-media-loading">Loading media…</p>`;
  try {
    const res = await fetch("/demo-media/media.json", { cache: "no-store" });
    if (!res.ok) throw new Error(`HTTP ${res.status}`);
    const data = (await res.json()) as {
      proof?: Record<string, boolean>;
      mediaListing?: { images?: string[]; files?: string[] };
      note?: string;
    };
    const proof = data.proof ?? {};
    const images = (data.mediaListing?.images ?? []).join(", ") || "(none)";
    const files = (data.mediaListing?.files ?? []).join(", ") || "(none)";
    root.innerHTML = `
      <p>media/ is truth · index holds metadata only.</p>
      <ul class="schema-type-list" style="margin-top:0.75rem" data-harness="inspector-media-proof">
        <li class="schema-type-row"><span class="schema-type-name">Markdown image</span><span class="schema-type-meta">${
          proof.pageHasMarkdownImage ? "✓" : "?"
        }</span></li>
        <li class="schema-type-row"><span class="schema-type-name">Blob not in index</span><span class="schema-type-meta">${
          proof.blobNotInIndex ? "✓" : "?"
        }</span></li>
        <li class="schema-type-row"><span class="schema-type-name">Images</span><span class="schema-type-meta">${escapeAttr(
          images,
        )}</span></li>
        <li class="schema-type-row"><span class="schema-type-name">Files</span><span class="schema-type-meta">${escapeAttr(
          files,
        )}</span></li>
      </ul>
      <p class="inspector-hint" style="margin-top:0.75rem">${escapeAttr(
        data.note ?? "Attach via MediaServing; Photos/drop are Apple stubs.",
      )}</p>
    `;
  } catch {
    root.innerHTML = `<p>Missing media fixture. Run <code>./scripts/demo-media.sh</code>.</p>`;
  }
}

render();

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
import { renderMarkdownDebug } from "./panels/MarkdownDebugPanel";
import { renderSearchIndex } from "./panels/SearchIndexPanel";
import { renderSettingsVault } from "./panels/SettingsVaultPanel";
import { renderTypesSchema } from "./panels/TypesSchemaPanel";

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
  search: "⌕",
  types: "▦",
  settings: "⚙",
  gallery: "◈",
  markdown: "¶",
  editor: "✎",
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
  if (panelId === "search") {
    void renderSearchIndex(detail);
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
    const res = await fetch("/demo-created-today/created-today.json", { cache: "no-store" });
    if (!res.ok) throw new Error(`HTTP ${res.status}`);
    const data = (await res.json()) as {
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
    root.innerHTML = `
      <p>Index-only · daily.md ${data.proof?.dailyUnchanged ? "unchanged ✓" : "?"} after create.</p>
      <ul class="schema-type-list" data-harness="inspector-created-list" style="margin-top:0.75rem">
        ${rows || "<li class='schema-type-row'>Empty</li>"}
      </ul>
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
      return "Created today";
    case "search":
      return "Filters";
    case "types":
      return "Pages · type metadata";
    case "settings":
      return "Sync status";
    case "gallery":
      return "Tokens";
    case "markdown":
      return "BlockAST";
    case "editor":
      return "Slash · keymap";
  }
}

render();

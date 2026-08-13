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
import { renderDestinationPlaceholder } from "./panels/DestinationPanel";
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
        <p>${panel.inspector}</p>
        <p class="inspector-hint">macOS: trailing split · iOS: sheet / secondary stack</p>
      </aside>
    </div>
  `;

  const detail = app.querySelector<HTMLElement>("[data-detail-root]");
  if (!detail) return;

  renderDetail(active, detail);

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
  }
}

render();

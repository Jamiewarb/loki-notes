import "./styles.css";
import { NAV_ITEMS, PANELS, type PanelId } from "./shell";
import { renderDesignGallery } from "./panels/DesignGalleryPanel";

const app = document.querySelector<HTMLDivElement>("#app");
if (!app) {
  throw new Error("#app missing");
}

let active: PanelId = "gallery";

function render(): void {
  const panel = PANELS[active];
  app.innerHTML = `
    <div class="shell" data-harness="loci-shell">
      <header class="brand-bar">
        <h1 class="brand">Loci</h1>
        <p class="brand-tag">DevHarness — visual shell for Cloud agent testing. Vault is truth; index is local.</p>
      </header>
      <aside class="sidebar" aria-label="Primary">
        <nav class="nav">
          ${NAV_ITEMS.map(
            (item) => `
              <button
                type="button"
                class="nav-btn"
                data-nav="${item.id}"
                aria-current="${item.id === active ? "page" : "false"}"
              >${item.label}</button>
            `,
          ).join("")}
        </nav>
        <p class="harness-note">Add panels in <code>src/panels/</code> and register in <code>shell.ts</code>.</p>
      </aside>
      <main class="detail" data-panel="${panel.id}">
        <div data-detail-root></div>
      </main>
      <aside class="inspector" aria-label="Inspector">
        <h3>Inspector</h3>
        <p>${panel.inspector}</p>
      </aside>
    </div>
  `;

  const detail = app.querySelector<HTMLElement>("[data-detail-root]");
  if (!detail) return;

  if (active === "gallery") {
    renderDesignGallery(detail);
  } else {
    detail.innerHTML = `
      <h2>${panel.title}</h2>
      <p>${panel.body}</p>
      <div class="placeholder-surface">
        Detail surface placeholder — SwiftUI AppShell arrives in PR03.
      </div>
    `;
  }

  app.querySelectorAll<HTMLButtonElement>("[data-nav]").forEach((btn) => {
    btn.addEventListener("click", () => {
      const id = btn.dataset.nav as PanelId;
      if (id && id !== active) {
        active = id;
        render();
      }
    });
  });
}

render();

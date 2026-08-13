/**
 * Design gallery panel — mirrors LociDesignSystem tokens + primitives for Linux visual proof.
 * Keep hex / spacing / type sizes in sync with Swift Tokens/*.
 */

const COLORS: { name: string; hex: string; varName: string }[] = [
  { name: "Ink", hex: "#1A2421", varName: "--loci-ink" },
  { name: "Ink soft", hex: "#3D4A45", varName: "--loci-ink-soft" },
  { name: "Paper", hex: "#E8EFE8", varName: "--loci-paper" },
  { name: "Paper deep", hex: "#D2DDD4", varName: "--loci-paper-deep" },
  { name: "Accent", hex: "#0F6B5C", varName: "--loci-accent" },
  { name: "Accent soft", hex: "#C5E4DC", varName: "--loci-accent-soft" },
  { name: "Mist", hex: "#B8D4C8", varName: "--loci-mist" },
  { name: "Danger", hex: "#9B3A2F", varName: "--loci-danger" },
];

const SPACING = [
  { token: "xxs", value: 2 },
  { token: "xs", value: 4 },
  { token: "sm", value: 8 },
  { token: "md", value: 12 },
  { token: "lg", value: 16 },
  { token: "xl", value: 24 },
  { token: "xxl", value: 32 },
  { token: "xxxl", value: 48 },
];

const TYPE_ROLES = [
  { role: "brand", size: 44, family: "display" },
  { role: "display", size: 28, family: "display" },
  { role: "title", size: 22, family: "display" },
  { role: "headline", size: 17, family: "body" },
  { role: "body", size: 16, family: "body" },
  { role: "callout", size: 14, family: "body" },
  { role: "caption", size: 12, family: "body" },
];

export function renderDesignGallery(root: HTMLElement): void {
  root.innerHTML = `
    <div class="gallery" data-harness="destination" data-destination="gallery">
      <header class="gallery-intro">
        <p class="gallery-kicker">LociDesignSystem · PR02</p>
        <h2 class="gallery-title">Design gallery</h2>
        <p class="gallery-lead">
          Editorial sage studio — brand <strong>Loci</strong> first. Soft paper, forest ink,
          moss-teal accent. Fraunces + Source Sans 3.
        </p>
      </header>

      <section class="gallery-section" aria-labelledby="colors-h">
        <h3 id="colors-h">Colors</h3>
        <p class="gallery-caption">Token hexes mirror <code>LociColors</code>.</p>
        <div class="swatch-grid">
          ${COLORS.map(
            (c) => `
            <div class="swatch">
              <div class="swatch-chip" style="background: var(${c.varName})"></div>
              <div class="swatch-meta">
                <span>${c.name}</span>
                <code>${c.hex}</code>
              </div>
            </div>`,
          ).join("")}
        </div>
      </section>

      <section class="gallery-section" aria-labelledby="type-h">
        <h3 id="type-h">Typography</h3>
        <p class="gallery-caption">Display Fraunces · body Source Sans 3.</p>
        <div class="type-stack">
          ${TYPE_ROLES.map(
            (t) => `
            <div class="type-row" style="font-family: var(--loci-font-${t.family}); font-size: ${t.size}px; font-weight: ${
              t.family === "display" ? 700 : 600
            }">
              <span class="type-label">${t.role}</span>
              <span>The quick loci notes · ${t.size}pt</span>
            </div>`,
          ).join("")}
        </div>
      </section>

      <section class="gallery-section" aria-labelledby="space-h">
        <h3 id="space-h">Spacing</h3>
        <p class="gallery-caption">Ascending scale from <code>LociSpacing</code>.</p>
        <div class="space-stack">
          ${SPACING.map(
            (s) => `
            <div class="space-row">
              <span class="space-token">${s.token}</span>
              <div class="space-bar" style="width: ${s.value * 4}px"></div>
              <span class="space-val">${s.value}</span>
            </div>`,
          ).join("")}
        </div>
      </section>

      <section class="gallery-section" aria-labelledby="comp-h">
        <h3 id="comp-h">Components</h3>
        <p class="gallery-caption">CSS stand-ins for LociButton, LociTextField, LociListRow, LociEmptyState.</p>

        <div class="comp-row">
          <button type="button" class="loci-btn loci-btn-primary">Primary</button>
          <button type="button" class="loci-btn loci-btn-secondary">Secondary</button>
          <button type="button" class="loci-btn loci-btn-quiet">Quiet</button>
          <button type="button" class="loci-btn loci-btn-destructive">Delete</button>
        </div>

        <label class="loci-field">
          <span class="loci-field-label">Title</span>
          <input class="loci-input" type="text" value="A page about gardens" />
        </label>

        <div class="loci-list" role="list">
          <button type="button" class="loci-list-row is-selected" role="listitem">
            <span class="loci-list-title">Daily</span>
            <span class="loci-list-sub">Today’s note</span>
          </button>
          <button type="button" class="loci-list-row" role="listitem">
            <span class="loci-list-title">Search</span>
            <span class="loci-list-sub">Full-text index</span>
          </button>
        </div>

        <hr class="loci-divider" />

        <div class="loci-empty">
          <div class="loci-empty-icon" aria-hidden="true">◇</div>
          <h4>No pages yet</h4>
          <p>Create a Page object — vault files are source of truth.</p>
          <button type="button" class="loci-btn loci-btn-primary loci-btn-narrow">New Page</button>
        </div>
      </section>

      <section class="gallery-section" aria-labelledby="motion-h">
        <h3 id="motion-h">Motion</h3>
        <p class="gallery-caption">Brand rise 0.70s · shell 0.52s · panel 0.28s (see LociMotion).</p>
        <button type="button" class="loci-btn loci-btn-secondary" data-replay-motion>Replay appear</button>
        <div class="motion-demo" data-motion-target>
          <span class="motion-brand">Loci</span>
          <span class="motion-soft">soft appear</span>
        </div>
      </section>
    </div>
  `;

  const replay = root.querySelector<HTMLButtonElement>("[data-replay-motion]");
  const target = root.querySelector<HTMLElement>("[data-motion-target]");
  replay?.addEventListener("click", () => {
    if (!target) return;
    target.classList.remove("is-playing");
    void target.offsetWidth;
    target.classList.add("is-playing");
  });
  target?.classList.add("is-playing");

  const rows = root.querySelectorAll<HTMLButtonElement>(".loci-list-row");
  rows.forEach((row) => {
    row.addEventListener("click", () => {
      rows.forEach((r) => r.classList.remove("is-selected"));
      row.classList.add("is-selected");
    });
  });
}

/**
 * Safari web clipper panel (PR32).
 * Loads `/demo-safari/safari.json` from `scripts/demo-safari.sh`.
 */
export async function renderSafariPanel(root: HTMLElement): Promise<void> {
  root.innerHTML = `
    <div class="destination safari-panel" data-harness="destination" data-destination="safari">
      <header class="destination-header">
        <span class="destination-icon" aria-hidden="true">◎</span>
        <h2 class="destination-title">Safari</h2>
      </header>
      <p class="destination-lead">
        Clip selection/page → today’s daily or Weblink. Extension writes inbox JSON only.
      </p>
      <p class="vault-note" data-harness="safari-status">Loading Safari demo…</p>
    </div>
  `;

  const status = root.querySelector("[data-harness='safari-status']");
  try {
    const res = await fetch("/demo-safari/safari.json", { cache: "no-store" });
    if (!res.ok) throw new Error(`HTTP ${res.status}`);
    const data = (await res.json()) as {
      moduleVersion: string;
      indexInsideVault: boolean;
      dailyLine: string;
      weblinkPath: string;
      weblinkURL?: string;
      pendingAfterDrain: number;
      proof: Record<string, boolean>;
      note: string;
      dailyBody?: string;
    };

    const proofRows = Object.entries(data.proof || {})
      .map(
        ([k, v]) => `
        <div>
          <dt>${escapeAttr(k)}</dt>
          <dd data-harness="safari-proof-${escapeAttr(k)}">${v ? "yes ✓" : "NO"}</dd>
        </div>`,
      )
      .join("");

    root.innerHTML = `
      <div class="destination safari-panel" data-harness="destination" data-destination="safari">
        <header class="destination-header">
          <span class="destination-icon" aria-hidden="true">◎</span>
          <h2 class="destination-title">Safari</h2>
        </header>
        <p class="destination-lead">
          Web clipper (${escapeAttr(data.moduleVersion)}).
        </p>

        <section class="vault-card" data-harness="safari-daily" aria-label="Daily clip">
          <p class="vault-kicker">PR38 · Inbox → daily / Weblink · menu bar</p>
          <h3 class="vault-card-title">Daily line</h3>
          <pre class="capture-body" data-harness="safari-daily-line">${escapeAttr(
            data.dailyLine || "",
          )}</pre>
        </section>

        <section class="vault-card" aria-label="Weblink">
          <h3 class="vault-card-title">Weblink object</h3>
          <dl class="vault-meta">
            <div>
              <dt>Path</dt>
              <dd data-harness="safari-weblink-path">${escapeAttr(data.weblinkPath || "—")}</dd>
            </div>
            <div>
              <dt>URL property</dt>
              <dd data-harness="safari-weblink-url">${escapeAttr(data.weblinkURL || "—")}</dd>
            </div>
            <div>
              <dt>Inbox empty</dt>
              <dd data-harness="safari-inbox-empty">${
                data.pendingAfterDrain === 0 ? "yes ✓" : "NO"
              }</dd>
            </div>
            <div>
              <dt>Index in vault</dt>
              <dd data-harness="safari-index-in-vault">${
                data.indexInsideVault ? "YES (bad)" : "no ✓"
              }</dd>
            </div>
          </dl>
          <dl class="vault-meta capture-proof-grid">${proofRows}</dl>
          <p class="vault-note">${escapeAttr(data.note || "")}</p>
        </section>
      </div>
    `;
  } catch (err) {
    if (status) {
      status.innerHTML = `Missing Safari fixture. Run <code>./scripts/demo-safari.sh</code>. (${escapeAttr(
        String(err),
      )})`;
    }
  }
}

function escapeAttr(value: string): string {
  return value
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;");
}

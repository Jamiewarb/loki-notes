/**
 * Daily panel — today’s note fixture from `scripts/demo-daily.sh` (PR10).
 * Loads `/demo-daily/daily.json`.
 */
export async function renderDailyPanel(root: HTMLElement): Promise<void> {
  root.innerHTML = `
    <div class="destination daily-panel" data-harness="destination" data-destination="daily">
      <header class="destination-header">
        <span class="destination-icon" aria-hidden="true">☀</span>
        <h2 class="destination-title">Daily</h2>
      </header>
      <p class="destination-lead">
        Today’s note — deterministic <code>daily/YYYY-MM-DD.md</code> + id <code>daily-YYYY-MM-DD</code>.
      </p>
      <p class="vault-note" data-harness="daily-status">Loading daily demo…</p>
    </div>
  `;

  const status = root.querySelector("[data-harness='daily-status']");
  try {
    const res = await fetch("/demo-daily/daily.json", { cache: "no-store" });
    if (!res.ok) throw new Error(`HTTP ${res.status}`);
    const data = (await res.json()) as {
      moduleVersion: string;
      indexInsideVault: boolean;
      idempotent: boolean;
      scheme: {
        path: string;
        logicalId: string;
        examplePath: string;
        exampleId: string;
        exampleUUID: string;
      };
      today: {
        id: string;
        title: string;
        relativePath: string;
        bodyPreview: string;
      };
      yesterday: {
        id: string;
        title: string;
        relativePath: string;
      };
      dayNav: { prev: string; today: string; next: string };
      markdown: string;
      note: string;
    };

    root.innerHTML = `
      <div class="destination daily-panel" data-harness="destination" data-destination="daily">
        <header class="destination-header">
          <span class="destination-icon" aria-hidden="true">☀</span>
          <h2 class="destination-title">Daily</h2>
        </header>
        <p class="destination-lead">
          Auto-create today · prev/next day · BlockEditor host in the app.
          <code>${escapeHtml(data.moduleVersion)}</code>
        </p>

        <section class="vault-card" data-harness="daily-meta" aria-label="Daily identity">
          <p class="vault-kicker">PR10 · Deterministic identity</p>
          <h3 class="vault-card-title">${escapeHtml(data.today.title)}</h3>
          <dl class="vault-meta">
            <div>
              <dt>Path</dt>
              <dd><code data-harness="daily-path">${escapeHtml(data.scheme.examplePath)}</code></dd>
            </div>
            <div>
              <dt>Logical id</dt>
              <dd><code data-harness="daily-id">${escapeHtml(data.scheme.exampleId)}</code></dd>
            </div>
            <div>
              <dt>UUID (derived)</dt>
              <dd><code>${escapeHtml(data.scheme.exampleUUID)}</code></dd>
            </div>
            <div>
              <dt>Idempotent ensure</dt>
              <dd data-harness="daily-idempotent">${data.idempotent ? "yes" : "no"}</dd>
            </div>
            <div>
              <dt>Index in vault</dt>
              <dd>${data.indexInsideVault ? "FAIL" : "never"}</dd>
            </div>
          </dl>
        </section>

        <section class="vault-card" data-harness="daily-nav" aria-label="Day navigation">
          <p class="vault-kicker">Day switcher</p>
          <p class="vault-card-body">
            <span data-harness="daily-prev">${escapeHtml(data.dayNav.prev)}</span>
            ←
            <strong data-harness="daily-today">${escapeHtml(data.dayNav.today)}</strong>
            →
            <span data-harness="daily-next">${escapeHtml(data.dayNav.next)}</span>
          </p>
          <p class="vault-card-body">
            Yesterday file: <code>${escapeHtml(data.yesterday.relativePath)}</code>
            (<code>${escapeHtml(data.yesterday.id)}</code>)
          </p>
        </section>

        <section class="vault-card" data-harness="daily-body" aria-label="Today markdown">
          <p class="vault-kicker">Body preview</p>
          <pre class="code-block" data-harness="daily-markdown">${escapeHtml(data.markdown)}</pre>
        </section>

        <p class="vault-note" data-harness="daily-status">
          ${escapeHtml(data.note)} Regenerate with <code>./scripts/demo-daily.sh</code>.
          Created-today inspector is PR11.
        </p>
      </div>
    `;
  } catch (err) {
    if (status) {
      status.textContent =
        err instanceof Error ? err.message : "Failed to load demo-daily fixtures";
    }
    const note = document.createElement("p");
    note.className = "vault-note";
    note.textContent = "Missing demo-daily fixtures. Run ./scripts/demo-daily.sh then reload.";
    root.appendChild(note);
  }
}

function escapeHtml(value: string): string {
  return value
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;");
}

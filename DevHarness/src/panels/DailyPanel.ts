/**
 * Daily panel — today’s note + Created today (PR10/PR11).
 * Loads `/demo-daily/daily.json` and `/demo-created-today/created-today.json`.
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
    const [dailyRes, createdRes] = await Promise.all([
      fetch("/demo-daily/daily.json", { cache: "no-store" }),
      fetch("/demo-created-today/created-today.json", { cache: "no-store" }),
    ]);
    if (!dailyRes.ok) throw new Error(`daily.json HTTP ${dailyRes.status}`);
    const data = (await dailyRes.json()) as {
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

    let created: {
      createdToday?: Array<{
        id: string;
        type: string;
        title: string;
        relativePath: string;
      }>;
      proof?: { dailyUnchanged?: boolean; beforeHash?: string; afterHash?: string };
      excludeDailyFromPanel?: boolean;
      note?: string;
      moduleVersion?: string;
    } | null = null;
    if (createdRes.ok) {
      created = await createdRes.json();
    }

    const createdRows = (created?.createdToday ?? [])
      .map(
        (h) => `
        <li class="schema-type-row" data-harness="created-today-row" data-object-id="${escapeHtml(
          h.id,
        )}" role="button" tabindex="0">
          <span class="schema-type-name">${escapeHtml(h.title)}</span>
          <span class="schema-type-meta">${escapeHtml(h.type)} · ${escapeHtml(h.relativePath)}</span>
        </li>`,
      )
      .join("");

    const proofOk = created?.proof?.dailyUnchanged === true;
    const proofLabel = created
      ? proofOk
        ? "daily .md unchanged after Page create ✓"
        : "FAIL — daily .md mutated"
      : "run ./scripts/demo-created-today.sh";

    root.innerHTML = `
      <div class="destination daily-panel" data-harness="destination" data-destination="daily">
        <header class="destination-header">
          <span class="destination-icon" aria-hidden="true">☀</span>
          <h2 class="destination-title">Daily</h2>
        </header>
        <p class="destination-lead">
          Auto-create today · prev/next day · Created-today inspector (index-only).
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

        <section class="vault-card" data-harness="created-today-section" aria-label="Created today">
          <p class="vault-kicker">PR11 · IndexQuerying.created(on:)</p>
          <h3 class="vault-card-title">Created today</h3>
          <p class="vault-card-body" data-harness="created-today-proof">
            Proof: <strong data-harness="daily-unchanged">${escapeHtml(proofLabel)}</strong>
            · exclude Daily type from panel: ${created?.excludeDailyFromPanel ? "yes" : "n/a"}
          </p>
          <ul class="schema-type-list" data-harness="created-today-list">
            ${createdRows || "<li class='schema-type-row'>No created-today fixtures — run ./scripts/demo-created-today.sh</li>"}
          </ul>
          <div class="page-detail" data-harness="created-today-detail" hidden>
            <p class="vault-kicker">Harness detail</p>
            <p class="vault-card-body" data-harness="created-today-detail-body"></p>
          </div>
          <p class="vault-note">
            ${escapeHtml(created?.note ?? "UI-only links; never rewrite daily.md.")}
            Regenerate with <code>./scripts/demo-created-today.sh</code>.
          </p>
        </section>

        <p class="vault-note" data-harness="daily-status">
          ${escapeHtml(data.note)} Regenerate daily with <code>./scripts/demo-daily.sh</code>.
        </p>
      </div>
    `;

    const detail = root.querySelector<HTMLElement>("[data-harness='created-today-detail']");
    const detailBody = root.querySelector<HTMLElement>("[data-harness='created-today-detail-body']");
    const items = created?.createdToday ?? [];
    root.querySelectorAll<HTMLLIElement>("[data-harness='created-today-row']").forEach((row) => {
      const show = () => {
        const id = row.dataset.objectId ?? "";
        const hit = items.find((h) => h.id === id);
        if (!detail || !detailBody) return;
        detail.hidden = false;
        detailBody.textContent = hit
          ? `Navigate → open object ${hit.title} (${hit.relativePath})\nApp uses Navigating.open(objectID:); harness shows detail placeholder.`
          : "Unknown object";
        detail.dataset.objectId = id;
      };
      row.addEventListener("click", show);
      row.addEventListener("keydown", (ev) => {
        if (ev.key === "Enter" || ev.key === " ") {
          ev.preventDefault();
          show();
        }
      });
    });
  } catch (err) {
    if (status) {
      status.textContent =
        err instanceof Error ? err.message : "Failed to load demo-daily fixtures";
    }
    const note = document.createElement("p");
    note.className = "vault-note";
    note.textContent =
      "Missing fixtures. Run ./scripts/demo-daily.sh and ./scripts/demo-created-today.sh then reload.";
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

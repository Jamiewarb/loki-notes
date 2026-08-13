/**
 * Import panel — dry-run + apply (PR27).
 * Loads `/demo-import/import.json` from `scripts/demo-import.sh`.
 */
export async function renderImportPanel(root: HTMLElement): Promise<void> {
  root.innerHTML = `
    <div class="destination import-panel" data-harness="destination" data-destination="import">
      <header class="destination-header">
        <span class="destination-icon" aria-hidden="true">⇩</span>
        <h2 class="destination-title">Import</h2>
      </header>
      <p class="destination-lead">
        Markdown folder · Obsidian · Capacities — dry-run summary, then vault apply.
      </p>
      <p class="vault-note" data-harness="import-status">Loading import demo…</p>
    </div>
  `;

  const status = root.querySelector("[data-harness='import-status']");
  try {
    const res = await fetch("/demo-import/import.json", { cache: "no-store" });
    if (!res.ok) throw new Error(`HTTP ${res.status}`);
    const data = (await res.json()) as {
      moduleVersion: string;
      indexModuleVersion?: string;
      indexInsideVault: boolean;
      runs: Array<{
        name: string;
        kind: string;
        detected: string;
        dryRun: {
          items: number;
          media: number;
          create: number;
          skip: number;
          daily: number;
          preservedIDs: number;
          warnings: string[];
        };
        apply: {
          written: number;
          skipped: number;
          mediaCopied: number;
          preservedIDs: number;
        };
        samplePaths?: string[];
        dailyPath?: string;
        dailyID?: string;
      }>;
      importers: Array<{ id: string; label: string }>;
      proof: Record<string, boolean>;
      note: string;
    };

    const proofRows = Object.entries(data.proof || {})
      .map(
        ([k, v]) => `
        <div>
          <dt>${escapeAttr(k)}</dt>
          <dd data-harness="import-proof-${escapeAttr(k)}">${v ? "yes ✓" : "NO"}</dd>
        </div>`,
      )
      .join("");

    const importers = (data.importers || [])
      .map(
        (s) => `
        <li class="import-importer" data-harness="import-importer" data-importer="${escapeAttr(s.id)}">
          <strong>${escapeAttr(s.label)}</strong>
        </li>`,
      )
      .join("");

    const runCards = (data.runs || [])
      .map(
        (r) => `
        <section class="vault-card" data-harness="import-run" data-run="${escapeAttr(r.name)}">
          <p class="vault-kicker">${escapeAttr(r.name)} · ${escapeAttr(r.kind)}</p>
          <h3 class="vault-card-title">Dry-run → apply</h3>
          <dl class="vault-meta">
            <div><dt>Detected</dt><dd>${escapeAttr(r.detected)}</dd></div>
            <div><dt>Items</dt><dd>${r.dryRun?.items ?? 0}</dd></div>
            <div><dt>Media</dt><dd>${r.dryRun?.media ?? 0}</dd></div>
            <div><dt>Written</dt><dd data-harness="import-written">${r.apply?.written ?? 0}</dd></div>
            <div><dt>Preserved IDs</dt><dd>${r.apply?.preservedIDs ?? 0}</dd></div>
            ${
              r.dailyPath
                ? `<div><dt>Daily</dt><dd data-harness="import-daily">${escapeAttr(r.dailyPath)} (${escapeAttr(r.dailyID || "")})</dd></div>`
                : ""
            }
          </dl>
          <ul class="import-paths">
            ${(r.samplePaths || [])
              .map((p) => `<li><code>${escapeAttr(p)}</code></li>`)
              .join("")}
          </ul>
        </section>`,
      )
      .join("");

    root.innerHTML = `
      <div class="destination import-panel" data-harness="destination" data-destination="import">
        <header class="destination-header">
          <span class="destination-icon" aria-hidden="true">⇩</span>
          <h2 class="destination-title">Import</h2>
        </header>
        <p class="destination-lead">
          Dry-run before apply
          (${escapeAttr(data.moduleVersion)} / ${escapeAttr(data.indexModuleVersion ?? "")}).
        </p>

        <section class="vault-card" data-harness="import-proof" aria-label="Import proof">
          <p class="vault-kicker">PR27 · objects/ · daily/ · media/</p>
          <h3 class="vault-card-title">Proof</h3>
          <dl class="vault-meta">
            <div>
              <dt>Index in vault</dt>
              <dd>${data.indexInsideVault ? "YES (bad)" : "no ✓"}</dd>
            </div>
          </dl>
          <dl class="vault-meta import-proof-grid">${proofRows}</dl>
        </section>

        <section class="vault-card" aria-label="Importers">
          <p class="vault-kicker">Importers</p>
          <ul class="import-importers" data-harness="import-importers">${importers}</ul>
        </section>

        ${runCards}

        <p class="vault-note">${escapeAttr(data.note)}</p>
      </div>
    `;
  } catch (err) {
    if (status) {
      status.innerHTML = `Missing import fixture. Run <code>./scripts/demo-import.sh</code>. (${escapeAttr(
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

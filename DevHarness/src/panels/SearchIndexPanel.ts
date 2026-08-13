/**
 * Search / index panel — demos LociIndex FTS + created(on:) from exported JSON (PR07).
 * Loads `/demo-index/search.json` produced by `scripts/demo-index.sh`.
 */
export async function renderSearchIndex(root: HTMLElement): Promise<void> {
  root.innerHTML = `
    <div class="destination search-index" data-harness="destination" data-destination="search">
      <header class="destination-header">
        <span class="destination-icon" aria-hidden="true">⌕</span>
        <h2 class="destination-title">Search</h2>
      </header>
      <p class="destination-lead">
        Local SQLite index (GRDB / FTS5). Vault files are truth; the index lives under Application Support — never inside the vault.
      </p>
      <p class="vault-note" data-harness="search-status">Loading index fixture…</p>
    </div>
  `;

  const status = root.querySelector("[data-harness='search-status']");
  try {
    const res = await fetch("/demo-index/search.json", { cache: "no-store" });
    if (!res.ok) throw new Error(`HTTP ${res.status} — run ./scripts/demo-index.sh`);
    const data = (await res.json()) as {
      moduleVersion: string;
      sqliteEngine: string;
      vaultRoot: string;
      indexPath: string;
      vaultID: string;
      indexInsideVault: boolean;
      objectCount: number;
      searchQuery: string;
      searchHits: Array<{ id: string; type: string; title: string; relativePath: string; tags: string[] }>;
      createdHits: Array<{ id: string; type: string; title: string; relativePath: string }>;
      pages: Array<{ id: string; type: string; title: string; relativePath: string }>;
      note: string;
    };

    const hitRows = data.searchHits
      .map(
        (h) => `
        <li class="schema-type-row" data-harness="search-hit" data-object-id="${escapeHtml(h.id)}">
          <span class="schema-type-name">${escapeHtml(h.title)}</span>
          <span class="schema-type-meta">${escapeHtml(h.type)} · ${escapeHtml(h.relativePath)}</span>
        </li>`,
      )
      .join("");

    const createdRows = data.createdHits
      .map(
        (h) => `
        <li class="schema-type-row" data-harness="created-hit">
          <span class="schema-type-name">${escapeHtml(h.title)}</span>
          <span class="schema-type-meta">${escapeHtml(h.relativePath)}</span>
        </li>`,
      )
      .join("");

    root.innerHTML = `
      <div class="destination search-index" data-harness="destination" data-destination="search">
        <header class="destination-header">
          <span class="destination-icon" aria-hidden="true">⌕</span>
          <h2 class="destination-title">Search</h2>
        </header>
        <p class="destination-lead">
          IndexQuerying demo via <code>LociIndex</code> (${escapeHtml(data.moduleVersion)} · ${escapeHtml(data.sqliteEngine)}).
        </p>

        <section class="vault-card" data-harness="search-meta" aria-label="Index status">
          <p class="vault-kicker">PR07 · LociIndex</p>
          <h3 class="vault-card-title">Local projection</h3>
          <dl class="vault-meta">
            <div>
              <dt>Engine</dt>
              <dd>${escapeHtml(data.sqliteEngine)} · FTS5</dd>
            </div>
            <div>
              <dt>Objects indexed</dt>
              <dd data-harness="search-object-count">${data.objectCount}</dd>
            </div>
            <div>
              <dt>Index inside vault?</dt>
              <dd data-harness="search-index-in-vault">${data.indexInsideVault ? "YES (bug)" : "no ✓"}</dd>
            </div>
            <div>
              <dt>Vault ID</dt>
              <dd><code>${escapeHtml(data.vaultID)}</code></dd>
            </div>
          </dl>
        </section>

        <section class="vault-card" aria-label="FTS search hits">
          <p class="vault-kicker">search("${escapeHtml(data.searchQuery)}")</p>
          <h3 class="vault-card-title">FTS hits</h3>
          <ul class="schema-type-list" data-harness="search-hit-list">
            ${hitRows || "<li class='schema-type-row'>No hits</li>"}
          </ul>
        </section>

        <section class="vault-card" aria-label="Created on day">
          <p class="vault-kicker">created(on:)</p>
          <h3 class="vault-card-title">Created that day</h3>
          <ul class="schema-type-list" data-harness="created-hit-list">
            ${createdRows || "<li class='schema-type-row'>None</li>"}
          </ul>
        </section>

        <p class="vault-note" data-harness="search-note">
          ${escapeHtml(data.note)} Regenerate with <code>./scripts/demo-index.sh</code>.
        </p>
      </div>
    `;
  } catch (err) {
    if (status) {
      status.textContent = `Failed to load demo-index fixture: ${err instanceof Error ? err.message : String(err)}`;
    }
  }
}

function escapeHtml(s: string): string {
  return s
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;");
}

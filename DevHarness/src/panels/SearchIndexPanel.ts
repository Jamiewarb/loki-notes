/**
 * Search panel — global FTS via IndexQuerying.search (PR18).
 * Loads `/demo-search/search.json` from `scripts/demo-search.sh`.
 * Falls back to `/demo-index/search.json` (PR07) if the new fixture is missing.
 */
export async function renderSearchIndex(root: HTMLElement): Promise<void> {
  root.innerHTML = `
    <div class="destination search-index" data-harness="destination" data-destination="search">
      <header class="destination-header">
        <span class="destination-icon" aria-hidden="true">⌕</span>
        <h2 class="destination-title">Search</h2>
      </header>
      <p class="destination-lead">
        ⌘K / SearchView · FTS5 title + body · results grouped by type · index never in the vault.
      </p>
      <p class="vault-note" data-harness="search-status">Loading search fixture…</p>
    </div>
  `;

  const status = root.querySelector("[data-harness='search-status']");
  try {
    let res = await fetch("/demo-search/search.json", { cache: "no-store" });
    let source = "demo-search";
    if (!res.ok) {
      res = await fetch("/demo-index/search.json", { cache: "no-store" });
      source = "demo-index";
      if (!res.ok) throw new Error(`HTTP ${res.status} — run ./scripts/demo-search.sh`);
    }
    const data = (await res.json()) as {
      moduleVersion?: string;
      sqliteEngine?: string;
      vaultRoot?: string;
      indexPath?: string;
      vaultID?: string;
      indexInsideVault: boolean;
      objectCount: number;
      bulkSeeded?: number;
      searchQuery: string;
      ftsMatch?: string;
      searchHits: Array<{
        id: string;
        type: string;
        title: string;
        relativePath: string;
        tags?: string[];
        titleMatch?: boolean;
      }>;
      grouped?: Array<{
        type: string;
        title: string;
        items: Array<{ id: string; type: string; title: string; relativePath: string; titleMatch?: boolean }>;
      }>;
      titleHits?: Array<{ id: string; title: string; type: string }>;
      bodyHits?: Array<{ id: string; title: string; type: string }>;
      proof?: {
        titleHit?: boolean;
        bodyHit?: boolean;
        groupedByType?: boolean;
        titleFirst?: boolean;
        hitCount?: number;
        groupCount?: number;
        indexOutsideVault?: boolean;
      };
      note?: string;
    };

    const grouped = data.grouped ?? [];
    const groupSections =
      grouped.length > 0
        ? grouped
            .map((g) => {
              const rows = (g.items || [])
                .map(
                  (h) => `
                <li class="schema-type-row" data-harness="search-hit" data-object-id="${escapeHtml(h.id)}" data-type="${escapeHtml(h.type)}">
                  <span class="schema-type-name">${escapeHtml(h.title)}${h.titleMatch ? ' <em class="search-title-badge">title</em>' : ""}</span>
                  <span class="schema-type-meta">${escapeHtml(h.relativePath)}</span>
                </li>`,
                )
                .join("");
              return `
              <section class="vault-card" data-harness="search-group" data-type="${escapeHtml(g.type)}" aria-label="${escapeHtml(g.title)}">
                <p class="vault-kicker">${escapeHtml(g.title)}</p>
                <h3 class="vault-card-title">${(g.items || []).length} hit${(g.items || []).length === 1 ? "" : "s"}</h3>
                <ul class="schema-type-list" data-harness="search-hit-list">
                  ${rows || "<li class='schema-type-row'>No hits</li>"}
                </ul>
              </section>`;
            })
            .join("")
        : (() => {
            const hitRows = (data.searchHits || [])
              .map(
                (h) => `
              <li class="schema-type-row" data-harness="search-hit" data-object-id="${escapeHtml(h.id)}">
                <span class="schema-type-name">${escapeHtml(h.title)}</span>
                <span class="schema-type-meta">${escapeHtml(h.type)} · ${escapeHtml(h.relativePath)}</span>
              </li>`,
              )
              .join("");
            return `
              <section class="vault-card" aria-label="FTS search hits">
                <p class="vault-kicker">search("${escapeHtml(data.searchQuery)}")</p>
                <h3 class="vault-card-title">FTS hits</h3>
                <ul class="schema-type-list" data-harness="search-hit-list">
                  ${hitRows || "<li class='schema-type-row'>No hits</li>"}
                </ul>
              </section>`;
          })();

    const proof = data.proof ?? {};
    const proofBits = [
      proof.titleHit ? "title hit ✓" : null,
      proof.bodyHit ? "body hit ✓" : null,
      proof.groupedByType ? "grouped by type ✓" : null,
      proof.titleFirst ? "title ranked first ✓" : null,
      data.indexInsideVault ? "INDEX IN VAULT (bug)" : "index outside vault ✓",
    ]
      .filter(Boolean)
      .join(" · ");

    root.innerHTML = `
      <div class="destination search-index" data-harness="destination" data-destination="search">
        <header class="destination-header">
          <span class="destination-icon" aria-hidden="true">⌕</span>
          <h2 class="destination-title">Search</h2>
        </header>
        <p class="destination-lead">
          Global FTS (<code>IndexQuerying.search</code>) · ${escapeHtml(data.moduleVersion ?? "LociIndex")} · ${escapeHtml(data.sqliteEngine ?? "GRDB / FTS5")}.
        </p>

        <section class="vault-card" data-harness="search-meta" aria-label="Index status">
          <p class="vault-kicker">PR18 · ⌘K / SearchView</p>
          <h3 class="vault-card-title">Local projection</h3>
          <dl class="vault-meta">
            <div>
              <dt>Query</dt>
              <dd data-harness="search-query"><code>${escapeHtml(data.searchQuery)}</code>${data.ftsMatch ? ` → <code>${escapeHtml(data.ftsMatch)}</code>` : ""}</dd>
            </div>
            <div>
              <dt>Objects indexed</dt>
              <dd data-harness="search-object-count">${data.objectCount}${data.bulkSeeded ? ` (bulk ${data.bulkSeeded})` : ""}</dd>
            </div>
            <div>
              <dt>Hits</dt>
              <dd data-harness="search-hit-count">${proof.hitCount ?? data.searchHits?.length ?? 0}</dd>
            </div>
            <div>
              <dt>Index inside vault?</dt>
              <dd data-harness="search-index-in-vault">${data.indexInsideVault ? "YES (bug)" : "no ✓"}</dd>
            </div>
          </dl>
          <p class="vault-note" data-harness="search-proof">${escapeHtml(proofBits)}</p>
        </section>

        ${groupSections}

        <p class="vault-note" data-harness="search-note">
          ${escapeHtml(data.note ?? "FTS title + body hits grouped by type.")}
          Fixture: <code>${escapeHtml(source)}</code> · regenerate with <code>./scripts/demo-search.sh</code>.
        </p>
      </div>
    `;
  } catch (err) {
    if (status) {
      status.textContent = `Failed to load search fixture: ${err instanceof Error ? err.message : String(err)}`;
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

/**
 * Tags panel — Page + Book tagged #health; alias wellness→health (PR17).
 * Loads `/demo-tags/tags.json` from `scripts/demo-tags.sh`.
 */
export async function renderTagsPanel(root: HTMLElement): Promise<void> {
  root.innerHTML = `
    <div class="destination tags-panel" data-harness="destination" data-destination="tags">
      <header class="destination-header">
        <span class="destination-icon" aria-hidden="true">#</span>
        <h2 class="destination-title">Tags</h2>
      </header>
      <p class="destination-lead">
        Cross-type <code>#tags</code> · object frontmatter + body · aliases in space.json.
      </p>
      <p class="vault-note" data-harness="tags-status">Loading tags demo…</p>
    </div>
  `;

  const status = root.querySelector("[data-harness='tags-status']");
  try {
    const res = await fetch("/demo-tags/tags.json", { cache: "no-store" });
    if (!res.ok) throw new Error(`HTTP ${res.status}`);
    const data = (await res.json()) as {
      moduleVersion: string;
      page: { id: string; title: string; type: string; tags: string[]; relativePath: string };
      book: { id: string; title: string; type: string; relativePath: string; bodyMarkdown: string };
      healthObjects: Array<{ id: string; title: string; type: string; tags: string[] }>;
      tagSummaries: Array<{ tag: string; canonical: string; count: number; display: string }>;
      completer: Array<{ tag: string; count: number }>;
      aliases: Record<string, string[]>;
      proof: {
        healthCount: number;
        types: string[];
        crossType: boolean;
        aliasWellnessMatches: boolean;
        completerHasHealth: boolean;
        bodyHasHashHealth: boolean;
      };
      indexInsideVault: boolean;
      note: string;
    };

    const objects = (data.healthObjects ?? [])
      .map(
        (o) => `
        <li class="schema-type-row" data-harness="tag-object-row" data-type="${escapeAttr(o.type)}">
          <span class="schema-type-name">${escapeAttr(o.title)}</span>
          <span class="schema-type-meta">${escapeAttr(o.type)} · ${(o.tags || []).map((t) => "#" + t).join(" ")}</span>
        </li>`,
      )
      .join("");

    const summaries = (data.tagSummaries ?? [])
      .map(
        (s) => `
        <li class="schema-type-row" data-harness="tag-summary-row">
          <span class="schema-type-name">${escapeAttr(s.display)}</span>
          <span class="schema-type-meta">${s.count}</span>
        </li>`,
      )
      .join("");

    const completer = (data.completer ?? [])
      .map(
        (c) => `
        <li class="schema-type-row" data-harness="tag-completer-row">
          <span class="schema-type-name">#${escapeAttr(c.tag)}</span>
          <span class="schema-type-meta">${c.count}</span>
        </li>`,
      )
      .join("");

    const aliasBits = Object.entries(data.aliases ?? {})
      .map(([k, v]) => `${k} ← ${(v || []).join(", ")}`)
      .join(" · ");

    root.innerHTML = `
      <div class="destination tags-panel" data-harness="destination" data-destination="tags">
        <header class="destination-header">
          <span class="destination-icon" aria-hidden="true">#</span>
          <h2 class="destination-title">Tags</h2>
        </header>
        <p class="destination-lead">
          Tag browse is cross-type; index never lives in the vault
          (${escapeAttr(data.moduleVersion)}).
        </p>

        <section class="vault-card" data-harness="tags-proof" aria-label="Tag proof">
          <p class="vault-kicker">PR17 · #health across types</p>
          <h3 class="vault-card-title">${escapeAttr(data.page.title)} + ${escapeAttr(data.book.title)}</h3>
          <dl class="vault-meta">
            <div>
              <dt>#health objects</dt>
              <dd data-harness="tags-health-count">${data.proof.healthCount}</dd>
            </div>
            <div>
              <dt>Types</dt>
              <dd data-harness="tags-types">${escapeAttr((data.proof.types || []).join(", "))}</dd>
            </div>
            <div>
              <dt>Cross-type</dt>
              <dd>${data.proof.crossType ? "yes ✓" : "no"}</dd>
            </div>
            <div>
              <dt>Alias wellness→health</dt>
              <dd>${data.proof.aliasWellnessMatches ? "yes ✓" : "no"}</dd>
            </div>
            <div>
              <dt>Completer</dt>
              <dd>${data.proof.completerHasHealth ? "hea→health ✓" : "no"}</dd>
            </div>
            <div>
              <dt>Index in vault</dt>
              <dd>${data.indexInsideVault ? "YES (bad)" : "no ✓"}</dd>
            </div>
            <div>
              <dt>Aliases</dt>
              <dd>${escapeAttr(aliasBits || "(none)")}</dd>
            </div>
          </dl>
        </section>

        <section class="md-columns" aria-label="Tag page and completer">
          <div class="md-pane">
            <h3 class="md-pane-title">#health tag page</h3>
            <ul class="schema-type-list" data-harness="tag-objects-list">${objects || "<li>Empty</li>"}</ul>
          </div>
          <div class="md-pane">
            <h3 class="md-pane-title">All tags</h3>
            <ul class="schema-type-list" data-harness="tag-summaries-list">${summaries || "<li>Empty</li>"}</ul>
          </div>
        </section>

        <section class="vault-card" aria-label="Completer">
          <p class="vault-kicker"># completer</p>
          <h3 class="vault-card-title">Candidates matching “hea”</h3>
          <ul class="schema-type-list" data-harness="tag-completer-list">${completer || "<li>Empty</li>"}</ul>
        </section>

        <section class="md-columns" aria-label="Bodies">
          <div class="md-pane">
            <h3 class="md-pane-title">Page (frontmatter tags)</h3>
            <pre class="md-pre" data-harness="tags-page-meta">tags: [${(data.page.tags || []).join(", ")}]
${escapeAttr(data.page.relativePath)}</pre>
          </div>
          <div class="md-pane">
            <h3 class="md-pane-title">Book body (# insert)</h3>
            <pre class="md-pre" data-harness="tags-book-body">${escapeAttr(data.book.bodyMarkdown.trimEnd())}</pre>
          </div>
        </section>

        <p class="vault-note">${escapeAttr(data.note)}</p>
      </div>
    `;
  } catch (err) {
    if (status) {
      status.innerHTML = `Missing tags fixture. Run <code>./scripts/demo-tags.sh</code>. (${escapeAttr(
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

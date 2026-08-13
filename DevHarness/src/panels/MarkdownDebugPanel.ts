/**
 * Markdown debug panel — shows sample Loci MD → AST summary → round-trip (PR06).
 * Loads `/demo-markdown/roundtrip.json` produced by `scripts/demo-markdown.sh`.
 */
export async function renderMarkdownDebug(root: HTMLElement): Promise<void> {
  root.innerHTML = `
    <div class="destination markdown-debug" data-harness="destination" data-destination="markdown">
      <header class="destination-header">
        <span class="destination-icon" aria-hidden="true">¶</span>
        <h2 class="destination-title">Markdown</h2>
      </header>
      <p class="destination-lead">
        Loci MD ↔ BlockAST + YAML frontmatter. Files are truth; this panel only demos parse/serialize.
      </p>
      <p class="vault-note" data-harness="markdown-status">Loading round-trip fixture…</p>
    </div>
  `;

  const status = root.querySelector("[data-harness='markdown-status']");
  try {
    const res = await fetch("/demo-markdown/roundtrip.json", { cache: "no-store" });
    if (!res.ok) throw new Error(`HTTP ${res.status}`);
    const data = (await res.json()) as {
      moduleVersion: string;
      yamlChoice: string;
      input: string;
      output: string;
      frontMatter: Record<string, unknown>;
      blocks: string[];
      roundTripStable: boolean;
    };

    root.innerHTML = `
      <div class="destination markdown-debug" data-harness="destination" data-destination="markdown">
        <header class="destination-header">
          <span class="destination-icon" aria-hidden="true">¶</span>
          <h2 class="destination-title">Markdown</h2>
        </header>
        <p class="destination-lead">
          Sample fixture round-trip via <code>LociMarkdown</code> (${escapeHtml(data.moduleVersion)}).
        </p>

        <section class="vault-card" data-harness="markdown-meta" aria-label="Markdown kit status">
          <p class="vault-kicker">PR06 · LociMarkdown</p>
          <h3 class="vault-card-title">Parse → serialize</h3>
          <dl class="vault-meta">
            <div>
              <dt>YAML</dt>
              <dd>${escapeHtml(data.yamlChoice)}</dd>
            </div>
            <div>
              <dt>Frontmatter</dt>
              <dd><code>${escapeHtml(String(data.frontMatter.title ?? ""))}</code> · type ${escapeHtml(String(data.frontMatter.type ?? ""))}</dd>
            </div>
            <div>
              <dt>Blocks</dt>
              <dd data-harness="markdown-blocks">${escapeHtml(data.blocks.join(" · "))}</dd>
            </div>
            <div>
              <dt>Round-trip stable</dt>
              <dd data-harness="markdown-stable">${data.roundTripStable ? "yes" : "no"}</dd>
            </div>
          </dl>
        </section>

        <section class="md-columns" aria-label="Input and output markdown">
          <div class="md-pane">
            <h3 class="md-pane-title">Input</h3>
            <pre class="md-pre" data-harness="markdown-input">${escapeHtml(data.input.trimEnd())}</pre>
          </div>
          <div class="md-pane">
            <h3 class="md-pane-title">Serialized</h3>
            <pre class="md-pre" data-harness="markdown-output">${escapeHtml(data.output.trimEnd())}</pre>
          </div>
        </section>

        <p class="vault-note">
          Regenerate with <code>./scripts/demo-markdown.sh</code>. Indexer (PR07) will consume this AST — never store SQLite in the vault.
        </p>
      </div>
    `;
  } catch (err) {
    if (status) {
      status.textContent =
        "Missing demo-markdown fixtures. Run ./scripts/demo-markdown.sh then reload.";
    }
    console.warn("markdown panel", err);
  }
}

function escapeHtml(value: string): string {
  return value
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;");
}

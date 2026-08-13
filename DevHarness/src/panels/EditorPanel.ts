/**
 * Editor panel — EditorSession slash simulation + BlockAST HTML preview (PR09).
 * Loads `/demo-editor/editor.json` from `scripts/demo-editor.sh`.
 */
export async function renderEditorPanel(root: HTMLElement): Promise<void> {
  root.innerHTML = `
    <div class="destination editor-panel" data-harness="destination" data-destination="editor">
      <header class="destination-header">
        <span class="destination-icon" aria-hidden="true">✎</span>
        <h2 class="destination-title">Editor</h2>
      </header>
      <p class="destination-lead">
        Block editor MVP — EditorSession owns BlockAST; slash inserts serialize via LociMarkdown.
      </p>
      <p class="vault-note" data-harness="editor-status">Loading editor demo…</p>
    </div>
  `;

  const status = root.querySelector("[data-harness='editor-status']");
  try {
    const res = await fetch("/demo-editor/editor.json", { cache: "no-store" });
    if (!res.ok) throw new Error(`HTTP ${res.status}`);
    const data = (await res.json()) as {
      moduleVersion: string;
      blockCount: number;
      blocks: string[];
      serialized: string;
      html: string;
      roundTripStable: boolean;
      isDirty: boolean;
      slashSimulated: string[];
      note: string;
      queryEmbed?: {
        serialized?: string;
        html?: string;
        queryID?: string;
        storesResultsInBody?: boolean;
        roundTripKind?: string;
      };
    };

    const embed = data.queryEmbed;
    const embedSection = embed
      ? `
        <section class="vault-card" data-harness="query-embed-demo" aria-label="Query embed">
          <p class="vault-kicker">PR23 · /query embed</p>
          <h3 class="vault-card-title">Live query block</h3>
          <dl class="vault-meta">
            <div>
              <dt>Slug</dt>
              <dd data-harness="query-embed-id">${escapeHtml(embed.queryID ?? "?")}</dd>
            </div>
            <div>
              <dt>Stores results in body</dt>
              <dd data-harness="query-embed-stores">${embed.storesResultsInBody ? "yes" : "no"}</dd>
            </div>
            <div>
              <dt>Round-trip kind</dt>
              <dd>${escapeHtml(embed.roundTripKind ?? "?")}</dd>
            </div>
          </dl>
          <div class="md-columns" aria-label="Query embed markdown and HTML">
            <div class="md-pane">
              <h3 class="md-pane-title">Serialized embed</h3>
              <pre class="md-pre" data-harness="query-embed-serialized">${escapeHtml(
                (embed.serialized ?? "").trimEnd(),
              )}</pre>
            </div>
            <div class="md-pane">
              <h3 class="md-pane-title">AST HTML</h3>
              <div class="ast-html" data-harness="query-embed-html">${embed.html ?? ""}</div>
            </div>
          </div>
        </section>`
      : "";

    root.innerHTML = `
      <div class="destination editor-panel" data-harness="destination" data-destination="editor">
        <header class="destination-header">
          <span class="destination-icon" aria-hidden="true">✎</span>
          <h2 class="destination-title">Editor</h2>
        </header>
        <p class="destination-lead">
          Slash-style inserts via <code>EditorSession</code> (${escapeHtml(data.moduleVersion)}).
          Typing never awaits the index. <code>/query</code> embeds store a slug only.
        </p>

        <section class="vault-card" data-harness="editor-meta" aria-label="Editor session status">
          <p class="vault-kicker">PR09 · Block editor</p>
          <h3 class="vault-card-title">Session → serialize</h3>
          <dl class="vault-meta">
            <div>
              <dt>Blocks</dt>
              <dd data-harness="editor-blocks">${escapeHtml(data.blocks.join(" · "))}</dd>
            </div>
            <div>
              <dt>Count</dt>
              <dd data-harness="editor-count">${data.blockCount}</dd>
            </div>
            <div>
              <dt>Slash simulated</dt>
              <dd data-harness="editor-slash">${escapeHtml((data.slashSimulated ?? []).join(", "))}</dd>
            </div>
            <div>
              <dt>Round-trip stable</dt>
              <dd data-harness="editor-stable">${data.roundTripStable ? "yes" : "no"}</dd>
            </div>
            <div>
              <dt>Dirty after demo edits</dt>
              <dd>${data.isDirty ? "yes" : "no"}</dd>
            </div>
          </dl>
        </section>

        <section class="md-columns" aria-label="Serialized markdown and AST HTML">
          <div class="md-pane">
            <h3 class="md-pane-title">Serialized MD</h3>
            <pre class="md-pre" data-harness="editor-serialized">${escapeHtml(data.serialized.trimEnd())}</pre>
          </div>
          <div class="md-pane">
            <h3 class="md-pane-title">AST HTML preview</h3>
            <div class="ast-html" data-harness="editor-html">${data.html}</div>
          </div>
        </section>

        ${embedSection}

        <p class="vault-note">
          Regenerate with <code>./scripts/demo-editor.sh</code> and <code>./scripts/demo-queries.sh</code>.
        </p>
      </div>
    `;
  } catch (err) {
    if (status) {
      status.textContent =
        "Missing demo-editor fixtures. Run ./scripts/demo-editor.sh then reload.";
    }
    console.warn("editor panel", err);
  }
}

function escapeHtml(value: string): string {
  return value
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;");
}

/**
 * Links panel — wiki-link A→B + backlinks on B + broken-link styling (PR16).
 * Loads `/demo-links/links.json` from `scripts/demo-links.sh`.
 */
export async function renderLinksPanel(root: HTMLElement): Promise<void> {
  root.innerHTML = `
    <div class="destination links-panel" data-harness="destination" data-destination="links">
      <header class="destination-header">
        <span class="destination-icon" aria-hidden="true">⇉</span>
        <h2 class="destination-title">Links</h2>
      </header>
      <p class="destination-lead">
        Wiki-links <code>[[id|title]]</code> + <code>@</code> picker · backlinks from the local links index.
      </p>
      <p class="vault-note" data-harness="links-status">Loading links demo…</p>
    </div>
  `;

  const status = root.querySelector("[data-harness='links-status']");
  try {
    const res = await fetch("/demo-links/links.json", { cache: "no-store" });
    if (!res.ok) throw new Error(`HTTP ${res.status}`);
    const data = (await res.json()) as {
      moduleVersion: string;
      pageA: { id: string; title: string; relativePath: string; bodyMarkdown: string };
      pageB: { id: string; title: string; relativePath: string };
      backlinksOnB: Array<{ sourceId: string; sourceTitle: string; target: string }>;
      outgoingFromA: Array<{
        target: string;
        label?: string;
        resolvedTitle?: string;
        isBroken: boolean;
        styleClass: string;
      }>;
      resolve: { byId?: string; byPath?: string; brokenIsNil: boolean };
      pickerCandidates: Array<{ id: string; title: string; type: string }>;
      html: string;
      proof: {
        aLinksToB: boolean;
        backlinkCount: number;
        brokenCount: number;
        resolvedCount: number;
        preferredTargetIsObjectID: boolean;
      };
      indexInsideVault: boolean;
      note: string;
    };

    const backs = (data.backlinksOnB ?? [])
      .map(
        (b) => `
        <li class="schema-type-row" data-harness="backlink-row" data-source-id="${escapeAttr(b.sourceId)}">
          <span class="schema-type-name">${escapeAttr(b.sourceTitle)}</span>
          <span class="schema-type-meta">→ ${escapeAttr(b.target)}</span>
        </li>`,
      )
      .join("");

    const outgoing = (data.outgoingFromA ?? [])
      .map(
        (l) => `
        <li class="schema-type-row" data-harness="outgoing-row">
          <span class="${escapeAttr(l.styleClass)}" data-wiki-target="${escapeAttr(l.target)}">
            ${escapeAttr(l.label || l.resolvedTitle || l.target)}
          </span>
          <span class="schema-type-meta">${l.isBroken ? "broken" : "resolved"}</span>
        </li>`,
      )
      .join("");

    const candidates = (data.pickerCandidates ?? [])
      .map(
        (c) => `
        <li class="schema-type-row" data-harness="picker-row">
          <span class="schema-type-name">${escapeAttr(c.title)}</span>
          <span class="schema-type-meta">${escapeAttr(c.type)}</span>
        </li>`,
      )
      .join("");

    root.innerHTML = `
      <div class="destination links-panel" data-harness="destination" data-destination="links">
        <header class="destination-header">
          <span class="destination-icon" aria-hidden="true">⇉</span>
          <h2 class="destination-title">Links</h2>
        </header>
        <p class="destination-lead">
          LinkResolver prefers ObjectID; path/slug/title are secondary locators
          (${escapeAttr(data.moduleVersion)}).
        </p>

        <section class="vault-card" data-harness="links-proof" aria-label="Wiki-link proof">
          <p class="vault-kicker">PR16 · A → B → backlink</p>
          <h3 class="vault-card-title">${escapeAttr(data.pageA.title)} links to ${escapeAttr(data.pageB.title)}</h3>
          <dl class="vault-meta">
            <div>
              <dt>Backlinks on B</dt>
              <dd data-harness="links-backlink-count">${data.proof.backlinkCount}</dd>
            </div>
            <div>
              <dt>A → B</dt>
              <dd data-harness="links-a-to-b">${data.proof.aLinksToB ? "yes" : "no"}</dd>
            </div>
            <div>
              <dt>Target is ObjectID</dt>
              <dd>${data.proof.preferredTargetIsObjectID ? "yes" : "no"}</dd>
            </div>
            <div>
              <dt>Broken / resolved</dt>
              <dd>${data.proof.brokenCount} / ${data.proof.resolvedCount}</dd>
            </div>
            <div>
              <dt>Index in vault</dt>
              <dd>${data.indexInsideVault ? "YES (bad)" : "no ✓"}</dd>
            </div>
            <div>
              <dt>Resolve by id / path</dt>
              <dd>${escapeAttr(String(data.resolve.byId ?? "?"))} / ${escapeAttr(String(data.resolve.byPath ?? "?"))}</dd>
            </div>
          </dl>
        </section>

        <section class="md-columns" aria-label="Backlinks and outgoing">
          <div class="md-pane">
            <h3 class="md-pane-title">Backlinks on ${escapeAttr(data.pageB.title)}</h3>
            <ul class="schema-type-list" data-harness="backlinks-list">${backs || "<li>Empty</li>"}</ul>
          </div>
          <div class="md-pane">
            <h3 class="md-pane-title">Outgoing from ${escapeAttr(data.pageA.title)}</h3>
            <ul class="schema-type-list" data-harness="outgoing-list">${outgoing || "<li>Empty</li>"}</ul>
          </div>
        </section>

        <section class="vault-card" aria-label="Picker candidates">
          <p class="vault-kicker">@ / [[ picker</p>
          <h3 class="vault-card-title">Candidates matching “Page”</h3>
          <ul class="schema-type-list" data-harness="picker-list">${candidates || "<li>Empty</li>"}</ul>
        </section>

        <section class="md-columns" aria-label="Body and HTML">
          <div class="md-pane">
            <h3 class="md-pane-title">Page A body</h3>
            <pre class="md-pre" data-harness="links-body">${escapeAttr(data.pageA.bodyMarkdown.trimEnd())}</pre>
          </div>
          <div class="md-pane">
            <h3 class="md-pane-title">AST HTML (broken styling)</h3>
            <div class="ast-html" data-harness="links-html">${data.html}</div>
          </div>
        </section>

        <p class="vault-note">${escapeAttr(data.note)}</p>
      </div>
    `;
  } catch (err) {
    if (status) {
      status.innerHTML = `Missing links fixture. Run <code>./scripts/demo-links.sh</code>. (${escapeAttr(
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

/**
 * Capture panel — inbox staging → daily / typed object (PR26).
 * Loads `/demo-capture/capture.json` from `scripts/demo-capture.sh`.
 */
export async function renderCapturePanel(root: HTMLElement): Promise<void> {
  root.innerHTML = `
    <div class="destination capture-panel" data-harness="destination" data-destination="capture">
      <header class="destination-header">
        <span class="destination-icon" aria-hidden="true">⬇</span>
        <h2 class="destination-title">Capture</h2>
      </header>
      <p class="destination-lead">
        Share · widget · menu bar · staging <code>.loci/inbox/</code> → today / typed object.
      </p>
      <p class="vault-note" data-harness="capture-status">Loading capture demo…</p>
    </div>
  `;

  const status = root.querySelector("[data-harness='capture-status']");
  try {
    const res = await fetch("/demo-capture/capture.json", { cache: "no-store" });
    if (!res.ok) throw new Error(`HTTP ${res.status}`);
    const data = (await res.json()) as {
      moduleVersion: string;
      indexModuleVersion?: string;
      indexInsideVault: boolean;
      dayKey: string;
      dailyPath: string;
      dailyBody: string;
      pendingBefore: string[];
      pendingAfter: string[];
      enqueue: { appendPath: string; createPath: string };
      drain: Array<{
        kind: string;
        objectId: string;
        relativePath: string;
        inboxPath?: string;
        appendedLine?: string;
      }>;
      direct: { kind: string; relativePath: string; appendedLine?: string };
      createdObject: { path?: string; id?: string };
      surfaces: Array<{ id: string; label: string; action: string }>;
      proof: Record<string, boolean>;
      note: string;
    };

    const proofRows = Object.entries(data.proof || {})
      .map(
        ([k, v]) => `
        <div>
          <dt>${escapeAttr(k)}</dt>
          <dd data-harness="capture-proof-${escapeAttr(k)}">${v ? "yes ✓" : "NO"}</dd>
        </div>`,
      )
      .join("");

    const surfaces = (data.surfaces || [])
      .map(
        (s) => `
        <li class="capture-surface" data-harness="capture-surface" data-surface="${escapeAttr(s.id)}">
          <strong>${escapeAttr(s.label)}</strong>
          <span>${escapeAttr(s.action)}</span>
        </li>`,
      )
      .join("");

    const drainRows = (data.drain || [])
      .map(
        (r) => `
        <li data-harness="capture-drain-item">
          <code>${escapeAttr(r.kind)}</code> →
          <code>${escapeAttr(r.relativePath)}</code>
          ${r.appendedLine ? `<span class="capture-line">${escapeAttr(r.appendedLine)}</span>` : ""}
        </li>`,
      )
      .join("");

    root.innerHTML = `
      <div class="destination capture-panel" data-harness="destination" data-destination="capture">
        <header class="destination-header">
          <span class="destination-icon" aria-hidden="true">⬇</span>
          <h2 class="destination-title">Capture</h2>
        </header>
        <p class="destination-lead">
          Inbox → daily
          (${escapeAttr(data.moduleVersion)} / ${escapeAttr(data.indexModuleVersion ?? "")}).
        </p>

        <section class="vault-card" data-harness="capture-proof" aria-label="Capture proof">
          <p class="vault-kicker">PR38 · .loci/inbox · daily/${escapeAttr(data.dayKey)}.md</p>
          <h3 class="vault-card-title">Drain proof</h3>
          <dl class="vault-meta">
            <div>
              <dt>Daily path</dt>
              <dd data-harness="capture-daily-path">${escapeAttr(data.dailyPath)}</dd>
            </div>
            <div>
              <dt>Pending before</dt>
              <dd data-harness="capture-pending-before">${(data.pendingBefore || []).length}</dd>
            </div>
            <div>
              <dt>Pending after</dt>
              <dd data-harness="capture-pending-after">${(data.pendingAfter || []).length}</dd>
            </div>
            <div>
              <dt>Created object</dt>
              <dd data-harness="capture-created-path">${escapeAttr(data.createdObject?.path || "—")}</dd>
            </div>
            <div>
              <dt>Index in vault</dt>
              <dd>${data.indexInsideVault ? "YES (bad)" : "no ✓"}</dd>
            </div>
          </dl>
          <dl class="vault-meta capture-proof-grid">${proofRows}</dl>
        </section>

        <section class="vault-card" aria-label="Surfaces">
          <p class="vault-kicker">Surfaces</p>
          <ul class="capture-surfaces" data-harness="capture-surfaces">${surfaces}</ul>
        </section>

        <section class="vault-card" aria-label="Drain results">
          <p class="vault-kicker">Drain · ${data.drain?.length ?? 0} item(s)</p>
          <ul class="capture-drain" data-harness="capture-drain">${drainRows}</ul>
          <p class="vault-note" data-harness="capture-direct">
            Direct menu bar: ${escapeAttr(data.direct?.appendedLine || data.direct?.relativePath || "")}
          </p>
        </section>

        <section class="vault-card" aria-label="Daily body">
          <p class="vault-kicker">Today body</p>
          <pre class="capture-body" data-harness="capture-daily-body">${escapeAttr(data.dailyBody || "")}</pre>
        </section>

        <p class="vault-note">${escapeAttr(data.note)}</p>
      </div>
    `;
  } catch (err) {
    if (status) {
      status.innerHTML = `Missing capture fixture. Run <code>./scripts/demo-capture.sh</code>. (${escapeAttr(
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

/**
 * AI assist panel — summarize / rewrite / translate / autofill (PR30).
 * Loads `/demo-ai/ai.json` from `scripts/demo-ai.sh`.
 */
export async function renderAIPanel(root: HTMLElement): Promise<void> {
  root.innerHTML = `
    <div class="destination ai-panel" data-harness="destination" data-destination="ai">
      <header class="destination-header">
        <span class="destination-icon" aria-hidden="true">✧</span>
        <h2 class="destination-title">AI</h2>
      </header>
      <p class="destination-lead">
        Assist · BYOK · on-device heuristics. Never upload vault without opt-in.
      </p>
      <p class="vault-note" data-harness="ai-status">Loading AI demo…</p>
    </div>
  `;

  const status = root.querySelector("[data-harness='ai-status']");
  try {
    const res = await fetch("/demo-ai/ai.json", { cache: "no-store" });
    if (!res.ok) throw new Error(`HTTP ${res.status}`);
    const data = (await res.json()) as {
      moduleVersion: string;
      indexModuleVersion?: string;
      markdownModuleVersion?: string;
      indexInsideVault: boolean;
      credentialsInsideVault: boolean;
      uploadRefusedWithoutOptIn: boolean;
      summarize: { summary?: string; uploaded?: boolean; notes?: string[] };
      rewrite: { proposedBody?: string; uploaded?: boolean };
      translate: { proposedBody?: string; uploaded?: boolean };
      autofill: { proposedProperties?: Record<string, string>; notes?: string[] };
      book?: { path?: string; appliedUrl?: string; appliedStatus?: string };
      proof: Record<string, boolean>;
      note: string;
    };

    const proofRows = Object.entries(data.proof || {})
      .map(
        ([k, v]) => `
        <div>
          <dt>${escapeAttr(k)}</dt>
          <dd data-harness="ai-proof-${escapeAttr(k)}">${v ? "yes ✓" : "NO"}</dd>
        </div>`,
      )
      .join("");

    root.innerHTML = `
      <div class="destination ai-panel" data-harness="destination" data-destination="ai">
        <header class="destination-header">
          <span class="destination-icon" aria-hidden="true">✧</span>
          <h2 class="destination-title">AI</h2>
        </header>
        <p class="destination-lead">
          On-device heuristics
          (${escapeAttr(data.moduleVersion)} / ${escapeAttr(data.markdownModuleVersion ?? "")}).
        </p>

        <section class="vault-card" data-harness="ai-proof" aria-label="AI proof">
          <p class="vault-kicker">PR30 · Application Support credentials · ObjectServing apply</p>
          <h3 class="vault-card-title">Assist proof</h3>
          <dl class="vault-meta">
            <div>
              <dt>Summary</dt>
              <dd data-harness="ai-summary">${escapeAttr(data.summarize?.summary || "—")}</dd>
            </div>
            <div>
              <dt>Translated</dt>
              <dd data-harness="ai-translated">${escapeAttr(
                (data.translate?.proposedBody || "").split("\n").slice(0, 3).join(" · "),
              )}</dd>
            </div>
            <div>
              <dt>Autofill</dt>
              <dd data-harness="ai-autofill">${escapeAttr(
                JSON.stringify(data.autofill?.proposedProperties || {}),
              )}</dd>
            </div>
            <div>
              <dt>Upload refused</dt>
              <dd data-harness="ai-upload-refused">${
                data.uploadRefusedWithoutOptIn ? "yes ✓" : "NO"
              }</dd>
            </div>
            <div>
              <dt>Index in vault</dt>
              <dd data-harness="ai-index-in-vault">${data.indexInsideVault ? "YES (bad)" : "no ✓"}</dd>
            </div>
            <div>
              <dt>Credentials in vault</dt>
              <dd data-harness="ai-credentials-in-vault">${
                data.credentialsInsideVault ? "YES (bad)" : "no ✓"
              }</dd>
            </div>
          </dl>
          <dl class="vault-meta capture-proof-grid">${proofRows}</dl>
          <p class="vault-note">${escapeAttr(data.note || "")}</p>
          <pre class="capture-body" data-harness="ai-rewrite">${escapeAttr(
            data.rewrite?.proposedBody || "",
          )}</pre>
          <p class="vault-note" data-harness="ai-applied">
            Applied book: ${escapeAttr(data.book?.path || "—")} ·
            url=${escapeAttr(data.book?.appliedUrl || "—")} ·
            status=${escapeAttr(data.book?.appliedStatus || "—")}
          </p>
        </section>
      </div>
    `;
  } catch (err) {
    if (status) {
      status.innerHTML = `Missing AI fixture. Run <code>./scripts/demo-ai.sh</code>. (${escapeAttr(
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

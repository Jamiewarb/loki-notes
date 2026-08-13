/**
 * Safari web clipper panel (PR32) + weblink OG preview cache (PR43).
 * Loads `/demo-safari/safari.json` and `/demo-weblink-preview/weblink-preview.json`.
 */
export async function renderSafariPanel(root: HTMLElement): Promise<void> {
  root.innerHTML = `
    <div class="destination safari-panel" data-harness="destination" data-destination="safari">
      <header class="destination-header">
        <span class="destination-icon" aria-hidden="true">◎</span>
        <h2 class="destination-title">Safari</h2>
      </header>
      <p class="destination-lead">
        Clip selection/page → today’s daily or Weblink. Extension writes inbox JSON only.
      </p>
      <p class="vault-note" data-harness="safari-status">Loading Safari demo…</p>
    </div>
  `;

  const status = root.querySelector("[data-harness='safari-status']");
  try {
    const res = await fetch("/demo-safari/safari.json", { cache: "no-store" });
    if (!res.ok) throw new Error(`HTTP ${res.status}`);
    const data = (await res.json()) as {
      moduleVersion: string;
      indexInsideVault: boolean;
      dailyLine: string;
      weblinkPath: string;
      weblinkURL?: string;
      pendingAfterDrain: number;
      proof: Record<string, boolean>;
      note: string;
      dailyBody?: string;
    };

    const proofRows = Object.entries(data.proof || {})
      .map(
        ([k, v]) => `
        <div>
          <dt>${escapeAttr(k)}</dt>
          <dd data-harness="safari-proof-${escapeAttr(k)}">${v ? "yes ✓" : "NO"}</dd>
        </div>`,
      )
      .join("");

    const previewHTML = await renderWeblinkPreviewCard();

    root.innerHTML = `
      <div class="destination safari-panel" data-harness="destination" data-destination="safari">
        <header class="destination-header">
          <span class="destination-icon" aria-hidden="true">◎</span>
          <h2 class="destination-title">Safari</h2>
        </header>
        <p class="destination-lead">
          Web clipper (${escapeAttr(data.moduleVersion)}).
        </p>

        <section class="vault-card" data-harness="safari-daily" aria-label="Daily clip">
          <p class="vault-kicker">PR38 · Inbox → daily / Weblink · menu bar</p>
          <h3 class="vault-card-title">Daily line</h3>
          <pre class="capture-body" data-harness="safari-daily-line">${escapeAttr(
            data.dailyLine || "",
          )}</pre>
        </section>

        <section class="vault-card" aria-label="Weblink">
          <h3 class="vault-card-title">Weblink object</h3>
          <dl class="vault-meta">
            <div>
              <dt>Path</dt>
              <dd data-harness="safari-weblink-path">${escapeAttr(data.weblinkPath || "—")}</dd>
            </div>
            <div>
              <dt>URL property</dt>
              <dd data-harness="safari-weblink-url">${escapeAttr(data.weblinkURL || "—")}</dd>
            </div>
            <div>
              <dt>Inbox empty</dt>
              <dd data-harness="safari-inbox-empty">${
                data.pendingAfterDrain === 0 ? "yes ✓" : "NO"
              }</dd>
            </div>
            <div>
              <dt>Index in vault</dt>
              <dd data-harness="safari-index-in-vault">${
                data.indexInsideVault ? "YES (bad)" : "no ✓"
              }</dd>
            </div>
          </dl>
          <dl class="vault-meta capture-proof-grid">${proofRows}</dl>
          <p class="vault-note">${escapeAttr(data.note || "")}</p>
        </section>

        ${previewHTML}
      </div>
    `;
  } catch (err) {
    if (status) {
      status.innerHTML = `Missing Safari fixture. Run <code>./scripts/demo-safari.sh</code>. (${escapeAttr(
        String(err),
      )})`;
    }
  }
}

async function renderWeblinkPreviewCard(): Promise<string> {
  try {
    const res = await fetch("/demo-weblink-preview/weblink-preview.json", {
      cache: "no-store",
    });
    if (!res.ok) {
      throw new Error(`HTTP ${res.status}`);
    }
    const data = (await res.json()) as {
      previewTitle?: string;
      previewDescription?: string;
      previewImageURL?: string;
      weblinkURL?: string;
      weblinkPath?: string;
      cachePath?: string;
      cacheInsideVault?: boolean;
      indexInsideVault?: boolean;
      dailyUnchanged?: boolean;
      fetchCountAfterOpen?: number;
      fetchCountAfterTypingSave?: number;
      proof?: Record<string, boolean>;
      note?: string;
    };
    const proof = data.proof || {};
    const proofRows = Object.entries(proof)
      .map(
        ([k, v]) => `
        <div>
          <dt>${escapeAttr(k)}</dt>
          <dd data-harness="weblink-proof-${escapeAttr(k)}">${v ? "yes ✓" : "NO"}</dd>
        </div>`,
      )
      .join("");

    return `
      <section class="vault-card" data-harness="weblink-preview-card" aria-label="Link preview">
        <p class="vault-kicker">PR43 · OG preview cache · Application Support</p>
        <h3 class="vault-card-title">Link preview</h3>
        <p class="vault-card-body" data-harness="weblink-preview-title">${escapeAttr(
          data.previewTitle || "No preview",
        )}</p>
        <p class="vault-note" data-harness="weblink-preview-description">${escapeAttr(
          data.previewDescription || "",
        )}</p>
        <dl class="vault-meta">
          <div>
            <dt>Source URL</dt>
            <dd data-harness="weblink-preview-url">${escapeAttr(data.weblinkURL || "—")}</dd>
          </div>
          <div>
            <dt>Image URL</dt>
            <dd data-harness="weblink-preview-image">${escapeAttr(
              data.previewImageURL || "—",
            )}</dd>
          </div>
          <div>
            <dt>Cache path</dt>
            <dd data-harness="weblink-preview-cache">${escapeAttr(data.cachePath || "—")}</dd>
          </div>
          <div>
            <dt>Cache in vault</dt>
            <dd data-harness="weblink-cache-in-vault">${
              data.cacheInsideVault ? "YES (bad)" : "no ✓"
            }</dd>
          </div>
          <div>
            <dt>Index in vault</dt>
            <dd data-harness="weblink-index-in-vault">${
              data.indexInsideVault ? "YES (bad)" : "no ✓"
            }</dd>
          </div>
        </dl>
        <dl class="vault-meta capture-proof-grid">${proofRows}</dl>
        <p
          class="vault-note"
          data-harness="weblink-preview-note"
          data-daily-unchanged="${data.dailyUnchanged === true}"
          data-cache-inside-vault="${data.cacheInsideVault === true}"
          data-index-inside-vault="${proof.indexInsideVault === true}"
          data-parses-open-graph="${proof.parsesOpenGraph === true}"
          data-cache-outside-vault="${proof.cacheOutsideVault === true}"
          data-no-fetch-on-type="${proof.noFetchOnType === true}"
        >${escapeAttr(data.note || "")}</p>
      </section>
    `;
  } catch (err) {
    return `
      <section class="vault-card" data-harness="weblink-preview-card" aria-label="Link preview">
        <p class="vault-kicker">PR43 · OG preview cache</p>
        <h3 class="vault-card-title">Link preview</h3>
        <p class="vault-note" data-harness="weblink-preview-missing">
          Missing weblink preview fixture. Run <code>./scripts/demo-weblink-preview.sh</code>.
          (${escapeAttr(String(err))})
        </p>
      </section>
    `;
  }
}

function escapeAttr(value: string): string {
  return value
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;");
}

/**
 * Media panel — attach into media/ + markdown images + Image objects (PR20).
 * Loads `/demo-media/media.json` from `scripts/demo-media.sh`.
 */
export async function renderMediaPanel(root: HTMLElement): Promise<void> {
  root.innerHTML = `
    <div class="destination media-panel" data-harness="destination" data-destination="media">
      <header class="destination-header">
        <span class="destination-icon" aria-hidden="true">▣</span>
        <h2 class="destination-title">Media</h2>
      </header>
      <p class="destination-lead">
        Attach copies into media/images|files · markdown ![alt](…) · Image type — never SQLite blobs.
      </p>
      <p class="vault-note" data-harness="media-status">Loading media fixture…</p>
    </div>
  `;

  const status = root.querySelector("[data-harness='media-status']");
  try {
    const res = await fetch("/demo-media/media.json", { cache: "no-store" });
    if (!res.ok) throw new Error(`HTTP ${res.status} — run ./scripts/demo-media.sh`);
    const data = (await res.json()) as {
      moduleVersion?: string;
      indexInsideVault: boolean;
      imageAttachment?: Attachment;
      fileAttachment?: Attachment;
      page?: { title?: string; relativePath?: string; bodyMarkdown?: string };
      imageObject?: {
        title?: string;
        relativePath?: string;
        mediaPath?: string;
        bodyMarkdown?: string;
      };
      mediaListing?: { images?: string[]; files?: string[] };
      proof?: Record<string, boolean>;
      note?: string;
    };

    const proof = data.proof ?? {};
    const proofBits = [
      proof.imageInMediaImages ? "image → media/images ✓" : null,
      proof.fileInMediaFiles ? "file → media/files ✓" : null,
      proof.pageHasMarkdownImage ? "page markdown image ✓" : null,
      proof.imageObjectCreated ? "Image object ✓" : null,
      proof.blobNotInIndex ? "blob not in index ✓" : null,
      data.indexInsideVault ? "INDEX IN VAULT (bug)" : "index outside vault ✓",
    ]
      .filter(Boolean)
      .join(" · ");

    const images = (data.mediaListing?.images ?? [])
      .map(
        (n) =>
          `<li class="schema-type-row" data-harness="media-image-row"><span class="schema-type-name">${escapeHtml(
            n,
          )}</span><span class="schema-type-meta">media/images</span></li>`,
      )
      .join("");
    const files = (data.mediaListing?.files ?? [])
      .map(
        (n) =>
          `<li class="schema-type-row" data-harness="media-file-row"><span class="schema-type-name">${escapeHtml(
            n,
          )}</span><span class="schema-type-meta">media/files</span></li>`,
      )
      .join("");

    root.innerHTML = `
      <div class="destination media-panel" data-harness="destination" data-destination="media">
        <header class="destination-header">
          <span class="destination-icon" aria-hidden="true">▣</span>
          <h2 class="destination-title">Media</h2>
        </header>
        <p class="destination-lead">
          Vault media · ${escapeHtml(data.moduleVersion ?? "LociVault")} · coordinated write.
        </p>

        <section class="vault-card" data-harness="media-meta" aria-label="Media status">
          <p class="vault-kicker">PR20 · Attach</p>
          <h3 class="vault-card-title">Vault is truth</h3>
          <dl class="vault-meta">
            <div>
              <dt>Image path</dt>
              <dd data-harness="media-image-path"><code>${escapeHtml(
                data.imageAttachment?.relativePath ?? "",
              )}</code></dd>
            </div>
            <div>
              <dt>File path</dt>
              <dd data-harness="media-file-path"><code>${escapeHtml(
                data.fileAttachment?.relativePath ?? "",
              )}</code></dd>
            </div>
            <div>
              <dt>Index inside vault?</dt>
              <dd data-harness="media-index-in-vault">${data.indexInsideVault ? "YES (bug)" : "no ✓"}</dd>
            </div>
          </dl>
          <p class="vault-note" data-harness="media-proof">${escapeHtml(proofBits)}</p>
        </section>

        <section class="vault-card" data-harness="media-page" aria-label="Page with image">
          <p class="vault-kicker">Note</p>
          <h3 class="vault-card-title">${escapeHtml(data.page?.title ?? "Page")}</h3>
          <pre class="vault-card-body" data-harness="media-page-body" style="white-space:pre-wrap;font-size:0.85rem">${escapeHtml(
            data.page?.bodyMarkdown ?? "",
          )}</pre>
        </section>

        <section class="vault-card" data-harness="media-image-object" aria-label="Image object">
          <p class="vault-kicker">Image object</p>
          <h3 class="vault-card-title">${escapeHtml(data.imageObject?.title ?? "Image")}</h3>
          <dl class="vault-meta">
            <div>
              <dt>Object path</dt>
              <dd><code>${escapeHtml(data.imageObject?.relativePath ?? "")}</code></dd>
            </div>
            <div>
              <dt>media-path</dt>
              <dd data-harness="media-object-path"><code>${escapeHtml(
                data.imageObject?.mediaPath ?? "",
              )}</code></dd>
            </div>
          </dl>
        </section>

        <section class="vault-card" data-harness="media-listing" aria-label="Media folders">
          <p class="vault-kicker">Files</p>
          <h3 class="vault-card-title">media/ listing</h3>
          <ul class="schema-type-list" data-harness="media-images-list">${
            images || "<li class='schema-type-row'>No images</li>"
          }</ul>
          <ul class="schema-type-list" data-harness="media-files-list">${
            files || "<li class='schema-type-row'>No files</li>"
          }</ul>
        </section>

        <p class="vault-note" data-harness="media-note">
          ${escapeHtml(data.note ?? "Blobs only under media/; index never stores binaries.")}
          Regenerate with <code>./scripts/demo-media.sh</code>.
        </p>
      </div>
    `;
  } catch (err) {
    if (status) {
      status.textContent = `Failed to load media fixture: ${err instanceof Error ? err.message : String(err)}`;
    }
  }
}

type Attachment = {
  relativePath?: string;
  kind?: string;
  fileName?: string;
  byteCount?: number;
};

function escapeHtml(s: string): string {
  return s
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;");
}

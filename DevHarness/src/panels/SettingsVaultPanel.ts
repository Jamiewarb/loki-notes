/**
 * Settings / vault status panel — mirrors VaultSettingsView (PR04 + PR15 PARA).
 * Explains local Documents fallback + Apply PARA pack.
 */
export function renderSettingsVault(root: HTMLElement): void {
  root.innerHTML = `
    <div class="destination vault-settings" data-harness="destination" data-destination="settings">
      <header class="destination-header">
        <span class="destination-icon" aria-hidden="true">⚙</span>
        <h2 class="destination-title">Settings</h2>
      </header>
      <p class="destination-lead">
        Vault root, local Documents fallback, and sync status.
        Files are truth; the SQLite index never lives inside the vault.
      </p>

      <section class="vault-card" data-harness="vault-status" aria-label="Vault status">
        <p class="vault-kicker">PR04 · LociVault</p>
        <h3 class="vault-card-title">Create vault</h3>
        <p class="vault-card-body">
          On Apple builds, Settings → <strong>Create vault</strong> writes
          <code>.loci/space.json</code> under the ubiquity container (or local Documents fallback).
        </p>
        <dl class="vault-meta">
          <div>
            <dt>Root kind (Linux / CI)</dt>
            <dd data-harness="vault-root-kind">localDocuments</dd>
          </div>
          <div>
            <dt>Skeleton</dt>
            <dd><code>.loci/</code> · <code>daily/</code> · <code>objects/</code> · <code>media/</code></dd>
          </div>
          <div>
            <dt>Index location</dt>
            <dd>Application Support only — never inside the vault</dd>
          </div>
        </dl>
        <ol class="vault-steps">
          <li>Run package tests: <code>./scripts/test.sh</code> (VaultService + SchemaStore).</li>
          <li>Schema demo: <code>./scripts/demo-schema.sh</code> → writes Page type + harness fixtures.</li>
          <li>Optional CLI: <code>./scripts/demo-vault.sh</code> → prints vault path + sample daily note.</li>
          <li>macOS/iOS: open Settings and tap Create vault when iCloud or local sandbox is available.</li>
        </ol>
        <p class="vault-note">
          Identity is ObjectID (frontmatter), not absolute ubiquity URLs.
          Conflicted-copy filenames are detected via <code>ConflictedCopyDetector</code> for SyncStatus (PR21).
        </p>
      </section>

      <section class="vault-card" data-harness="para-pack" aria-label="PARA starter pack">
        <p class="vault-kicker">PR15 · PARA</p>
        <h3 class="vault-card-title">Apply PARA pack</h3>
        <p class="vault-card-body" data-harness="para-loading">Loading demo-para fixture…</p>
        <p class="vault-card-body" data-harness="para-explainer" hidden></p>
        <dl class="vault-meta" data-harness="para-meta" hidden>
          <div>
            <dt>Project</dt>
            <dd data-harness="para-project">—</dd>
          </div>
          <div>
            <dt>Area</dt>
            <dd data-harness="para-area">—</dd>
          </div>
          <div>
            <dt>Resource</dt>
            <dd data-harness="para-resource">tag:#resource (no type)</dd>
          </div>
          <div>
            <dt>Archive</dt>
            <dd data-harness="para-archive">tag:#archive + hide filter</dd>
          </div>
          <div>
            <dt>Idempotent re-apply</dt>
            <dd data-harness="para-idempotent">—</dd>
          </div>
          <div>
            <dt>Archived hidden (demo)</dt>
            <dd data-harness="para-filter">—</dd>
          </div>
        </dl>
        <p class="vault-note" data-harness="para-note" hidden></p>
        <p class="vault-note">
          Run <code>./scripts/demo-para.sh</code> → <code>/demo-para/para.json</code>.
          In the app: Settings → <strong>Apply PARA pack</strong> (idempotent).
        </p>
      </section>
    </div>
  `;

  void loadPARA(root);
}

async function loadPARA(root: HTMLElement): Promise<void> {
  const loading = root.querySelector<HTMLElement>("[data-harness='para-loading']");
  const explainer = root.querySelector<HTMLElement>("[data-harness='para-explainer']");
  const meta = root.querySelector<HTMLElement>("[data-harness='para-meta']");
  const note = root.querySelector<HTMLElement>("[data-harness='para-note']");
  if (!loading || !explainer || !meta || !note) return;

  try {
    const res = await fetch("/demo-para/para.json", { cache: "no-store" });
    if (!res.ok) throw new Error(`HTTP ${res.status}`);
    const data = (await res.json()) as {
      explainer?: string;
      resourceGuidance?: string;
      archiveGuidance?: string;
      space?: {
        paraPackApplied?: boolean;
        hideArchived?: boolean;
        resourceApproach?: string;
        archiveApproach?: string;
      };
      projectType?: { name?: string; defaultTemplateID?: string };
      areaType?: { name?: string; defaultTemplateID?: string };
      projectTemplate?: { id?: string; bodyPreview?: string };
      areaTemplate?: { id?: string; bodyPreview?: string };
      projectObject?: { title?: string; prefilled?: boolean };
      areaObject?: { title?: string; prefilled?: boolean };
      archiveFilter?: {
        allProjects?: number;
        visibleWhenHideArchived?: number;
        archivedHidden?: number;
        noFolderMove?: boolean;
      };
      idempotent?: boolean;
      resourceTypeExists?: boolean;
      note?: string;
      moduleVersion?: string;
    };

    loading.textContent = `PARA pack ${
      data.space?.paraPackApplied ? "applied ✓" : "?"
    } · ${data.moduleVersion ?? ""}`;
    explainer.hidden = false;
    explainer.textContent = data.explainer ?? "";
    meta.hidden = false;

    const projectEl = root.querySelector<HTMLElement>("[data-harness='para-project']");
    const areaEl = root.querySelector<HTMLElement>("[data-harness='para-area']");
    const resourceEl = root.querySelector<HTMLElement>("[data-harness='para-resource']");
    const archiveEl = root.querySelector<HTMLElement>("[data-harness='para-archive']");
    const idemEl = root.querySelector<HTMLElement>("[data-harness='para-idempotent']");
    const filterEl = root.querySelector<HTMLElement>("[data-harness='para-filter']");

    if (projectEl) {
      projectEl.textContent = `${data.projectType?.name ?? "Project"} · ${
        data.projectTemplate?.id ?? "?"
      } · prefill ${data.projectObject?.prefilled ? "✓" : "?"}`;
    }
    if (areaEl) {
      areaEl.textContent = `${data.areaType?.name ?? "Area"} · ${
        data.areaTemplate?.id ?? "?"
      } · prefill ${data.areaObject?.prefilled ? "✓" : "?"}`;
    }
    if (resourceEl) {
      resourceEl.textContent = `${data.space?.resourceApproach ?? "tag:#resource"} (type exists: ${
        data.resourceTypeExists ? "yes" : "no"
      })`;
    }
    if (archiveEl) {
      archiveEl.textContent = `${data.space?.archiveApproach ?? "tag:#archive"} · hideArchived=${
        data.space?.hideArchived ?? false
      }`;
    }
    if (idemEl) {
      idemEl.textContent = data.idempotent ? "yes ✓" : "no";
    }
    if (filterEl) {
      const f = data.archiveFilter ?? {};
      filterEl.textContent = `${f.archivedHidden ?? 0} hidden / ${f.allProjects ?? 0} projects · folder move: ${
        f.noFolderMove ? "none" : "?"
      }`;
    }

    note.hidden = false;
    note.textContent = data.note ?? data.resourceGuidance ?? "";
  } catch {
    loading.textContent = "Missing demo-para fixture. Run ./scripts/demo-para.sh";
  }
}

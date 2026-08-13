/**
 * Settings / vault + sync status panel — mirrors VaultSettingsView (PR04 + PR15 + PR21).
 */
export function renderSettingsVault(root: HTMLElement): void {
  root.innerHTML = `
    <div class="destination vault-settings" data-harness="destination" data-destination="settings">
      <header class="destination-header">
        <span class="destination-icon" aria-hidden="true">⚙</span>
        <h2 class="destination-title">Settings</h2>
      </header>
      <p class="destination-lead">
        Vault root, sync status chip, conflict list, rebuild index, and reveal vault path.
        Files are truth; the SQLite index never lives inside the vault.
      </p>

      <section class="vault-card" data-harness="sync-status" aria-label="Sync status">
        <p class="vault-kicker">PR21 · Sync UX</p>
        <h3 class="vault-card-title">Sync status</h3>
        <p class="vault-card-body" data-harness="sync-loading">Loading demo-sync fixture…</p>
        <div class="sync-chip-row" data-harness="sync-chip-row" hidden></div>
        <dl class="vault-meta" data-harness="sync-meta" hidden>
          <div>
            <dt>Live status (Linux)</dt>
            <dd data-harness="sync-live-status">—</dd>
          </div>
          <div>
            <dt>Vault path</dt>
            <dd data-harness="sync-vault-path">—</dd>
          </div>
          <div>
            <dt>Ensure downloaded</dt>
            <dd data-harness="sync-ensure">—</dd>
          </div>
          <div>
            <dt>Rebuild index</dt>
            <dd data-harness="sync-rebuild">—</dd>
          </div>
        </dl>
        <p class="vault-kicker" style="margin-top:0.75rem">Conflicts (markdown + media)</p>
        <ul class="schema-type-list" data-harness="sync-conflicts" hidden></ul>
        <p class="vault-kicker" style="margin-top:0.75rem">Simulated chip states</p>
        <div class="sync-sim-row" data-harness="sync-sim-row" hidden></div>
        <p class="vault-note" data-harness="sync-note" hidden></p>
        <p class="vault-note">
          Run <code>./scripts/demo-sync.sh</code> → <code>/demo-sync/sync.json</code>.
          In the app: Settings → Sync &amp; resilience · sidebar sync chip.
        </p>
      </section>

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
        <p class="vault-note">
          Identity is ObjectID (frontmatter), not absolute ubiquity URLs.
          Conflicted-copy filenames surface in SyncStatus conflict list (PR21).
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

  void loadSync(root);
  void loadPARA(root);
}

async function loadSync(root: HTMLElement): Promise<void> {
  const loading = root.querySelector<HTMLElement>("[data-harness='sync-loading']");
  const chipRow = root.querySelector<HTMLElement>("[data-harness='sync-chip-row']");
  const meta = root.querySelector<HTMLElement>("[data-harness='sync-meta']");
  const conflictsEl = root.querySelector<HTMLElement>("[data-harness='sync-conflicts']");
  const simRow = root.querySelector<HTMLElement>("[data-harness='sync-sim-row']");
  const note = root.querySelector<HTMLElement>("[data-harness='sync-note']");
  if (!loading || !chipRow || !meta || !conflictsEl || !simRow || !note) return;

  try {
    const res = await fetch("/demo-sync/sync.json", { cache: "no-store" });
    if (!res.ok) throw new Error(`HTTP ${res.status}`);
    const data = (await res.json()) as {
      status?: string;
      statusLabel?: string;
      vaultPath?: string;
      ensureDownloaded?: boolean;
      rebuildIndex?: boolean;
      conflicts?: Array<{ relativePath: string; kind: string; filename: string }>;
      simulatedStatuses?: Array<{ id: string; label: string }>;
      proof?: Record<string, boolean>;
      note?: string;
      moduleVersion?: string;
    };

    const proof = data.proof ?? {};
    loading.textContent = `Sync UX ${data.moduleVersion ?? ""} · ${
      proof.conflictStatusFromCopies ? "conflicts ✓" : "?"
    }`;

    chipRow.hidden = false;
    chipRow.innerHTML = `
      <span class="sync-chip is-live" data-harness="sync-chip" data-status="${escapeAttr(
        data.status ?? "localOnly",
      )}">${escapeAttr(data.statusLabel ?? "Local only")}</span>
    `;

    meta.hidden = false;
    const live = root.querySelector<HTMLElement>("[data-harness='sync-live-status']");
    const pathEl = root.querySelector<HTMLElement>("[data-harness='sync-vault-path']");
    const ensureEl = root.querySelector<HTMLElement>("[data-harness='sync-ensure']");
    const rebuildEl = root.querySelector<HTMLElement>("[data-harness='sync-rebuild']");
    if (live) live.textContent = `${data.statusLabel ?? "?"} (${data.status ?? "?"})`;
    if (pathEl) pathEl.textContent = data.vaultPath ?? "—";
    if (ensureEl) {
      ensureEl.textContent = proof.ensureDownloadedNoOp ? "no-op success ✓" : "?";
    }
    if (rebuildEl) {
      rebuildEl.textContent = proof.rebuildIndexOk ? "ok ✓" : "?";
    }

    const conflicts = data.conflicts ?? [];
    conflictsEl.hidden = false;
    conflictsEl.innerHTML =
      conflicts
        .map(
          (c) => `
        <li class="schema-type-row" data-harness="sync-conflict-row" data-kind="${escapeAttr(
          c.kind,
        )}">
          <span class="schema-type-name">${escapeAttr(c.filename)}</span>
          <span class="schema-type-meta">${escapeAttr(c.kind)} · ${escapeAttr(c.relativePath)}</span>
        </li>`,
        )
        .join("") || `<li class="schema-type-row">None</li>`;

    const sims = data.simulatedStatuses ?? [];
    simRow.hidden = false;
    simRow.innerHTML = sims
      .map(
        (s) =>
          `<button type="button" class="sync-chip" data-harness="sync-sim-chip" data-status="${escapeAttr(
            s.id,
          )}">${escapeAttr(s.label)}</button>`,
      )
      .join("");

    note.hidden = false;
    note.textContent = data.note ?? "";
  } catch {
    loading.textContent = "Missing demo-sync fixture. Run ./scripts/demo-sync.sh";
  }
}

function escapeAttr(value: string): string {
  return value
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;");
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

/**
 * Settings / vault status panel — mirrors VaultSettingsView (PR04).
 * Explains local Documents fallback + how to prove VaultService on Linux.
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
          <li>Run package tests: <code>./scripts/test.sh</code> (VaultService round-trip + trash).</li>
          <li>Optional CLI: <code>./scripts/demo-vault.sh</code> → prints vault path + writes sample daily note.</li>
          <li>macOS/iOS: open Settings and tap Create vault when iCloud or local sandbox is available.</li>
        </ol>
        <p class="vault-note">
          Identity is ObjectID (frontmatter), not absolute ubiquity URLs.
          Conflicted-copy filenames are detected via <code>ConflictedCopyDetector</code> for SyncStatus (PR21).
        </p>
      </section>
    </div>
  `;
}

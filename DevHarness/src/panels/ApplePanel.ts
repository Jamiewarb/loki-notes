/**
 * Apple Calendar / Reminders panel (PR31).
 * Loads `/demo-apple/apple.json` from `scripts/demo-apple.sh`.
 */
export async function renderApplePanel(root: HTMLElement): Promise<void> {
  root.innerHTML = `
    <div class="destination apple-panel" data-harness="destination" data-destination="apple">
      <header class="destination-header">
        <span class="destination-icon" aria-hidden="true">▦</span>
        <h2 class="destination-title">Apple</h2>
      </header>
      <p class="destination-lead">
        Calendar events · Meeting objects · Reminders sync. Event list is chrome — daily .md unchanged.
      </p>
      <p class="vault-note" data-harness="apple-status">Loading Apple demo…</p>
    </div>
  `;

  const status = root.querySelector("[data-harness='apple-status']");
  try {
    const res = await fetch("/demo-apple/apple.json", { cache: "no-store" });
    if (!res.ok) throw new Error(`HTTP ${res.status}`);
    const data = (await res.json()) as {
      moduleVersion: string;
      indexInsideVault: boolean;
      settingsInsideVault?: boolean;
      dailyUnchangedAfterEvents: boolean;
      reminderSynced: boolean;
      meetingIdempotent?: boolean;
      events: Array<{ id: string; title: string; location?: string }>;
      meeting: { path?: string; title?: string; eventId?: string };
      proof: Record<string, boolean>;
      note: string;
      dailyBodyAfterSync?: string;
      eventKitWired?: boolean;
      linuxUsesFakes?: boolean;
      dailyUnchanged?: boolean;
    };

    const events = data.events || [];
    const eventRows = events
      .map(
        (e) => `
        <li data-harness="apple-event">${escapeAttr(e.title)}${
          e.location ? ` · ${escapeAttr(e.location)}` : ""
        }</li>`,
      )
      .join("");

    const proofRows = Object.entries(data.proof || {})
      .map(
        ([k, v]) => `
        <div>
          <dt>${escapeAttr(k)}</dt>
          <dd data-harness="apple-proof-${escapeAttr(k)}">${v ? "yes ✓" : "NO"}</dd>
        </div>`,
      )
      .join("");

    root.innerHTML = `
      <div class="destination apple-panel" data-harness="destination" data-destination="apple">
        <header class="destination-header">
          <span class="destination-icon" aria-hidden="true">▦</span>
          <h2 class="destination-title">Apple</h2>
        </header>
        <p class="destination-lead">
          Calendar · Reminders (${escapeAttr(data.moduleVersion)}).
        </p>

        <section class="vault-card" data-harness="apple-events" aria-label="Events">
          <p class="vault-kicker">PR36 · EventKit on Apple · fakes on Linux · chrome only</p>
          <h3 class="vault-card-title">Events for day</h3>
          <ul class="vault-list">${eventRows || "<li>None</li>"}</ul>
        </section>

        <section class="vault-card" aria-label="Meeting">
          <h3 class="vault-card-title">Meeting object</h3>
          <dl class="vault-meta">
            <div>
              <dt>Path</dt>
              <dd data-harness="apple-meeting-path">${escapeAttr(data.meeting?.path || "—")}</dd>
            </div>
            <div>
              <dt>Title</dt>
              <dd>${escapeAttr(data.meeting?.title || "—")}</dd>
            </div>
            <div>
              <dt>Idempotent</dt>
              <dd>${data.meetingIdempotent ? "yes ✓" : "NO"}</dd>
            </div>
            <div>
              <dt>Daily unchanged</dt>
              <dd data-harness="apple-daily-unchanged">${
                data.dailyUnchangedAfterEvents ? "yes ✓" : "NO"
              }</dd>
            </div>
            <div>
              <dt>Reminder synced</dt>
              <dd data-harness="apple-reminder-synced">${
                data.reminderSynced ? "yes ✓" : "NO"
              }</dd>
            </div>
            <div>
              <dt>Index in vault</dt>
              <dd data-harness="apple-index-in-vault">${
                data.indexInsideVault ? "YES (bad)" : "no ✓"
              }</dd>
            </div>
          </dl>
          <dl class="vault-meta capture-proof-grid">${proofRows}</dl>
          <pre class="capture-body" data-harness="apple-daily-body">${escapeAttr(
            data.dailyBodyAfterSync || "",
          )}</pre>
          <p class="vault-note">${escapeAttr(data.note || "")}</p>
        </section>
      </div>
    `;
  } catch (err) {
    if (status) {
      status.innerHTML = `Missing Apple fixture. Run <code>./scripts/demo-apple.sh</code>. (${escapeAttr(
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

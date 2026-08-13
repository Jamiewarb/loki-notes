/**
 * Tasks panel — Today / Open aggregation via IndexQuerying (PR19).
 * Loads `/demo-tasks/tasks.json` from `scripts/demo-tasks.sh`.
 */
export async function renderTasksPanel(root: HTMLElement): Promise<void> {
  root.innerHTML = `
    <div class="destination tasks-panel" data-harness="destination" data-destination="tasks">
      <header class="destination-header">
        <span class="destination-icon" aria-hidden="true">☑</span>
        <h2 class="destination-title">Tasks</h2>
      </header>
      <p class="destination-lead">
        Today = daily note tasks · Open = incomplete across vault · toggles persist via ObjectServing.save.
      </p>
      <p class="vault-note" data-harness="tasks-status">Loading tasks fixture…</p>
    </div>
  `;

  const status = root.querySelector("[data-harness='tasks-status']");
  try {
    const res = await fetch("/demo-tasks/tasks.json", { cache: "no-store" });
    if (!res.ok) throw new Error(`HTTP ${res.status} — run ./scripts/demo-tasks.sh`);
    const data = (await res.json()) as {
      moduleVersion?: string;
      day?: string;
      dailyPath?: string;
      indexInsideVault: boolean;
      todayTasks?: TaskRow[];
      openTasks?: TaskRow[];
      completedTasks?: TaskRow[];
      proof?: {
        pageToggleCompleted?: boolean;
        dailyHasOpen?: boolean;
        openCount?: number;
        todayCount?: number;
        completedCount?: number;
        indexOutsideVault?: boolean;
      };
      note?: string;
    };

    const todayRows = renderTaskList(data.todayTasks ?? [], "today");
    const openRows = renderTaskList(data.openTasks ?? [], "open");
    const proof = data.proof ?? {};
    const proofBits = [
      proof.pageToggleCompleted ? "page toggle → completed ✓" : null,
      proof.dailyHasOpen ? "daily open task ✓" : null,
      data.indexInsideVault ? "INDEX IN VAULT (bug)" : "index outside vault ✓",
    ]
      .filter(Boolean)
      .join(" · ");

    root.innerHTML = `
      <div class="destination tasks-panel" data-harness="destination" data-destination="tasks">
        <header class="destination-header">
          <span class="destination-icon" aria-hidden="true">☑</span>
          <h2 class="destination-title">Tasks</h2>
        </header>
        <p class="destination-lead">
          IndexQuerying tasks · ${escapeHtml(data.moduleVersion ?? "LociIndex")} · day ${escapeHtml(data.day ?? "")}.
        </p>

        <section class="vault-card" data-harness="tasks-meta" aria-label="Tasks status">
          <p class="vault-kicker">PR19 · Today / Open</p>
          <h3 class="vault-card-title">Local projection</h3>
          <dl class="vault-meta">
            <div>
              <dt>Daily path</dt>
              <dd data-harness="tasks-daily-path"><code>${escapeHtml(data.dailyPath ?? "")}</code></dd>
            </div>
            <div>
              <dt>Today tasks</dt>
              <dd data-harness="tasks-today-count">${proof.todayCount ?? data.todayTasks?.length ?? 0}</dd>
            </div>
            <div>
              <dt>Open tasks</dt>
              <dd data-harness="tasks-open-count">${proof.openCount ?? data.openTasks?.length ?? 0}</dd>
            </div>
            <div>
              <dt>Index inside vault?</dt>
              <dd data-harness="tasks-index-in-vault">${data.indexInsideVault ? "YES (bug)" : "no ✓"}</dd>
            </div>
          </dl>
          <p class="vault-note" data-harness="tasks-proof">${escapeHtml(proofBits)}</p>
        </section>

        <section class="vault-card" data-harness="tasks-today" aria-label="Today tasks">
          <p class="vault-kicker">Today</p>
          <h3 class="vault-card-title">Daily note tasks</h3>
          <ul class="schema-type-list" data-harness="tasks-today-list">
            ${todayRows || "<li class='schema-type-row'>No tasks</li>"}
          </ul>
        </section>

        <section class="vault-card" data-harness="tasks-open" aria-label="Open tasks">
          <p class="vault-kicker">Open</p>
          <h3 class="vault-card-title">Incomplete across vault</h3>
          <ul class="schema-type-list" data-harness="tasks-open-list">
            ${openRows || "<li class='schema-type-row'>No open tasks</li>"}
          </ul>
        </section>

        <p class="vault-note" data-harness="tasks-note">
          ${escapeHtml(data.note ?? "Task checkboxes persist via ObjectServing.save → index.")}
          Regenerate with <code>./scripts/demo-tasks.sh</code>.
        </p>
      </div>
    `;
  } catch (err) {
    if (status) {
      status.textContent = `Failed to load tasks fixture: ${err instanceof Error ? err.message : String(err)}`;
    }
  }
}

type TaskRow = {
  id: string;
  text: string;
  completed: boolean;
  objectTitle?: string;
  relativePath?: string;
};

function renderTaskList(tasks: TaskRow[], kind: string): string {
  return tasks
    .map(
      (t) => `
      <li class="schema-type-row" data-harness="task-row" data-kind="${kind}" data-completed="${t.completed}">
        <span class="schema-type-name">${t.completed ? "☑" : "☐"} ${escapeHtml(t.text)}</span>
        <span class="schema-type-meta">${escapeHtml(t.objectTitle ?? "")} · ${escapeHtml(t.relativePath ?? "")}</span>
      </li>`,
    )
    .join("");
}

function escapeHtml(s: string): string {
  return s
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;");
}

/**
 * Calendar panel — month/week grid anchored to daily notes (PR25).
 * Loads `/demo-calendar/calendar.json` from `scripts/demo-calendar.sh`.
 */
export async function renderCalendarPanel(root: HTMLElement): Promise<void> {
  root.innerHTML = `
    <div class="destination calendar-panel" data-harness="destination" data-destination="calendar">
      <header class="destination-header">
        <span class="destination-icon" aria-hidden="true">▦</span>
        <h2 class="destination-title">Calendar</h2>
      </header>
      <p class="destination-lead">
        Month/week around daily notes · index dots · jump to <code>daily/YYYY-MM-DD.md</code>.
      </p>
      <p class="vault-note" data-harness="calendar-status">Loading calendar demo…</p>
    </div>
  `;

  const status = root.querySelector("[data-harness='calendar-status']");
  try {
    const res = await fetch("/demo-calendar/calendar.json", { cache: "no-store" });
    if (!res.ok) throw new Error(`HTTP ${res.status}`);
    const data = (await res.json()) as {
      moduleVersion: string;
      indexModuleVersion?: string;
      indexInsideVault: boolean;
      anchor: string;
      markers: Array<{
        dayKey: string;
        hasDailyNote: boolean;
        hasContent: boolean;
        creationCount: number;
        showsDot: boolean;
      }>;
      month: {
        title: string;
        weekdaySymbols: string[];
        cellCount: number;
        markedDayCount: number;
        cells: Array<{
          dayKey: string;
          inCurrentPeriod: boolean;
          isToday: boolean;
          isSelected: boolean;
          showsDot: boolean;
          dayNumber: number;
        }>;
      };
      week: {
        title: string;
        cellCount: number;
        cells: Array<{
          dayKey: string;
          showsDot: boolean;
          dayNumber: number;
          isSelected: boolean;
        }>;
      };
      jump: { day: string; path: string; objectId: string; daily13Unchanged: boolean };
      proof: Record<string, boolean>;
      note: string;
    };

    const month = data.month;
    const weekdays = (month.weekdaySymbols || [])
      .map((s) => `<span class="cal-weekday">${escapeAttr(s)}</span>`)
      .join("");

    const cells = (month.cells || [])
      .map((c) => {
        const classes = [
          "cal-cell",
          c.inCurrentPeriod ? "in-period" : "out-period",
          c.isToday ? "is-today" : "",
          c.isSelected ? "is-selected" : "",
          c.showsDot ? "has-dot" : "",
        ]
          .filter(Boolean)
          .join(" ");
        return `
          <button
            type="button"
            class="${classes}"
            data-harness="calendar-day"
            data-day-key="${escapeAttr(c.dayKey)}"
            data-shows-dot="${c.showsDot ? "true" : "false"}"
          >
            <span class="cal-day-num">${c.dayNumber}</span>
            <span class="cal-dot" aria-hidden="true"></span>
          </button>`;
      })
      .join("");

    root.innerHTML = `
      <div class="destination calendar-panel" data-harness="destination" data-destination="calendar">
        <header class="destination-header">
          <span class="destination-icon" aria-hidden="true">▦</span>
          <h2 class="destination-title">Calendar</h2>
        </header>
        <p class="destination-lead">
          Index-derived dots
          (${escapeAttr(data.moduleVersion)} / ${escapeAttr(data.indexModuleVersion ?? "")}).
        </p>

        <section class="vault-card" data-harness="calendar-proof" aria-label="Calendar proof">
          <p class="vault-kicker">PR25 · daily paths · index markers</p>
          <h3 class="vault-card-title">${escapeAttr(month.title)}</h3>
          <dl class="vault-meta">
            <div>
              <dt>Month cells</dt>
              <dd data-harness="calendar-cell-count">${month.cellCount}</dd>
            </div>
            <div>
              <dt>Marked</dt>
              <dd data-harness="calendar-marked-count">${month.markedDayCount}</dd>
            </div>
            <div>
              <dt>Week cells</dt>
              <dd data-harness="calendar-week-count">${data.week.cellCount}</dd>
            </div>
            <div>
              <dt>Jump</dt>
              <dd data-harness="calendar-jump-path">${escapeAttr(data.jump.path)}</dd>
            </div>
            <div>
              <dt>Daily 13 unchanged</dt>
              <dd>${data.jump.daily13Unchanged ? "yes ✓" : "NO"}</dd>
            </div>
            <div>
              <dt>Index in vault</dt>
              <dd>${data.indexInsideVault ? "YES (bad)" : "no ✓"}</dd>
            </div>
          </dl>
        </section>

        <section class="cal-grid-wrap" aria-label="Month grid">
          <div class="cal-toolbar">
            <span class="cal-title" data-harness="calendar-title">${escapeAttr(month.title)}</span>
            <span class="cal-scope">Month</span>
          </div>
          <div class="cal-weekdays">${weekdays}</div>
          <div class="cal-grid" data-harness="calendar-grid">${cells}</div>
          <p class="vault-note" data-harness="calendar-selection">
            Click a day — DailyNoteServing.ensure + Navigating.open in the app.
          </p>
        </section>

        <section class="vault-card" aria-label="Week strip">
          <p class="vault-kicker">Week · ${escapeAttr(data.week.title)}</p>
          <div class="cal-week-strip" data-harness="calendar-week">
            ${(data.week.cells || [])
              .map(
                (c) => `
              <div class="cal-week-day${c.showsDot ? " has-dot" : ""}${c.isSelected ? " is-selected" : ""}">
                <span>${c.dayNumber}</span>
                <span class="cal-dot" aria-hidden="true"></span>
              </div>`,
              )
              .join("")}
          </div>
        </section>

        <p class="vault-note">${escapeAttr(data.note)}</p>
      </div>
    `;

    const selection = root.querySelector<HTMLElement>("[data-harness='calendar-selection']");
    root.querySelectorAll<HTMLButtonElement>("[data-harness='calendar-day']").forEach((btn) => {
      btn.addEventListener("click", () => {
        const key = btn.getAttribute("data-day-key") ?? "";
        root.querySelectorAll(".cal-cell.is-selected").forEach((n) => n.classList.remove("is-selected"));
        btn.classList.add("is-selected");
        if (selection) {
          selection.textContent = `Open daily/${key}.md → DailyNoteServing.ensure + Navigating.open`;
        }
      });
    });
  } catch (err) {
    if (status) {
      status.innerHTML = `Missing calendar fixture. Run <code>./scripts/demo-calendar.sh</code>. (${escapeAttr(
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

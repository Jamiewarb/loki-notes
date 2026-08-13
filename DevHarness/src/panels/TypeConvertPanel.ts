/**
 * Type convert panel — property map + folder move (PR28).
 * Loads `/demo-type-convert/type-convert.json` from `scripts/demo-type-convert.sh`.
 */
export async function renderTypeConvertPanel(root: HTMLElement): Promise<void> {
  root.innerHTML = `
    <div class="destination type-convert-panel" data-harness="destination" data-destination="type-convert">
      <header class="destination-header">
        <span class="destination-icon" aria-hidden="true">⟲</span>
        <h2 class="destination-title">Convert type</h2>
      </header>
      <p class="destination-lead">
        Property mapping · move objects/&lt;type&gt;/ · ObjectID stable · index via ObjectServing.
      </p>
      <p class="vault-note" data-harness="type-convert-status">Loading type-convert demo…</p>
    </div>
  `;

  const status = root.querySelector("[data-harness='type-convert-status']");
  try {
    const res = await fetch("/demo-type-convert/type-convert.json", { cache: "no-store" });
    if (!res.ok) throw new Error(`HTTP ${res.status}`);
    const data = (await res.json()) as {
      moduleVersion: string;
      indexModuleVersion?: string;
      indexInsideVault: boolean;
      object: {
        id: string;
        title: string;
        sourceType: string;
        targetType: string;
        oldPath: string;
        newPath: string;
        mappedCount: number;
        droppedCount: number;
        properties?: Record<string, string>;
      };
      plan: {
        proposedPath: string;
        dropped: string[];
        mappings: Array<{ source: string; target: string }>;
      };
      proof: Record<string, boolean>;
      note: string;
    };

    const proofRows = Object.entries(data.proof || {})
      .map(
        ([k, v]) => `
        <div>
          <dt>${escapeAttr(k)}</dt>
          <dd data-harness="type-convert-proof-${escapeAttr(k)}">${v ? "yes ✓" : "NO"}</dd>
        </div>`,
      )
      .join("");

    const mapRows = (data.plan?.mappings || [])
      .map(
        (m) => `
        <li class="schema-type-row" data-harness="type-convert-map">
          <span class="schema-type-name">${escapeAttr(m.source)}</span>
          <span class="schema-type-meta">→ ${escapeAttr(m.target)}</span>
        </li>`,
      )
      .join("");

    const propRows = Object.entries(data.object?.properties || {})
      .map(
        ([k, v]) => `
        <li class="schema-type-row">
          <span class="schema-type-name">${escapeAttr(k)}</span>
          <span class="schema-type-meta">${escapeAttr(String(v))}</span>
        </li>`,
      )
      .join("");

    root.innerHTML = `
      <div class="destination type-convert-panel" data-harness="destination" data-destination="type-convert">
        <header class="destination-header">
          <span class="destination-icon" aria-hidden="true">⟲</span>
          <h2 class="destination-title">Convert type</h2>
        </header>
        <p class="destination-lead">
          ${escapeAttr(data.object.title)} · ${escapeAttr(data.object.sourceType)} → ${escapeAttr(
            data.object.targetType,
          )}
        </p>
        <section class="vault-card" data-harness="type-convert-result">
          <p class="vault-kicker">Move</p>
          <h3 class="vault-card-title">${escapeAttr(data.object.oldPath)}</h3>
          <p class="vault-card-body">→ ${escapeAttr(data.object.newPath)}</p>
          <p class="vault-card-body">id ${escapeAttr(data.object.id)} · mapped ${
            data.object.mappedCount
          } · dropped ${data.object.droppedCount}</p>
        </section>
        <p class="vault-kicker" style="margin-top:1rem">Property map</p>
        <ul class="schema-type-list" data-harness="type-convert-mappings">${
          mapRows || "<li>none</li>"
        }</ul>
        <p class="vault-kicker" style="margin-top:1rem">Result properties</p>
        <ul class="schema-type-list" data-harness="type-convert-props">${
          propRows || "<li>none</li>"
        }</ul>
        <dl class="vault-meta" data-harness="type-convert-proof" style="margin-top:1rem">
          ${proofRows}
        </dl>
        <p class="vault-note" data-harness="type-convert-note">${escapeAttr(data.note)}</p>
        <p class="harness-note">module ${escapeAttr(data.moduleVersion)} · index ${escapeAttr(
          data.indexModuleVersion ?? "—",
        )} · index inside vault: ${data.indexInsideVault ? "YES (bad)" : "no ✓"}</p>
      </div>
    `;
  } catch (err) {
    if (status) {
      status.innerHTML = `Missing type-convert fixture. Run <code>./scripts/demo-type-convert.sh</code>. (${escapeAttr(
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

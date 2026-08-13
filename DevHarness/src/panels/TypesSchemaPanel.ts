/**
 * Types / schema panel — mirrors TypeListView (PR05).
 * Loads fixtures from `/demo-schema/manifest.json` (written by scripts/demo-schema.sh).
 */
export async function renderTypesSchema(root: HTMLElement): Promise<void> {
  root.innerHTML = `
    <div class="destination types-schema" data-harness="destination" data-destination="types">
      <header class="destination-header">
        <span class="destination-icon" aria-hidden="true">▦</span>
        <h2 class="destination-title">Types</h2>
      </header>
      <p class="destination-lead">
        Schema lives under <code>.loci/types/</code> — one JSON file per type (merge-friendly).
        Built-in <strong>Page</strong> is seeded on vault create / <code>bootstrapSchema</code>.
      </p>
      <section class="vault-card" data-harness="types-status" aria-label="Schema types">
        <p class="vault-kicker">PR05 · SchemaStore</p>
        <h3 class="vault-card-title">Object types</h3>
        <p class="vault-card-body" data-harness="types-loading">Loading demo-schema fixtures…</p>
        <ul class="schema-type-list" data-harness="type-list" hidden></ul>
        <p class="vault-note" data-harness="types-note" hidden></p>
      </section>
    </div>
  `;

  const loading = root.querySelector<HTMLElement>("[data-harness='types-loading']");
  const list = root.querySelector<HTMLUListElement>("[data-harness='type-list']");
  const note = root.querySelector<HTMLElement>("[data-harness='types-note']");
  if (!loading || !list || !note) return;

  try {
    const res = await fetch("/demo-schema/manifest.json", { cache: "no-store" });
    if (!res.ok) {
      throw new Error(`HTTP ${res.status} — run ./scripts/demo-schema.sh to generate fixtures`);
    }
    const manifest = (await res.json()) as {
      space?: { name?: string; schemaVersion?: number };
      types?: Array<{
        id?: string;
        name?: string;
        icon?: string;
        isBuiltIn?: boolean;
        properties?: unknown[];
      }>;
      note?: string;
    };

    const types = manifest.types ?? [];
    const page = types.find((t) => t.id === "page");
    loading.textContent = `Space “${manifest.space?.name ?? "Loci"}” · schema v${
      manifest.space?.schemaVersion ?? 1
    } · ${types.length} type(s)`;

    list.hidden = false;
    list.innerHTML = types
      .map((t) => {
        const props = Array.isArray(t.properties) ? t.properties.length : 0;
        const builtIn = t.isBuiltIn ? " · built-in" : "";
        return `
          <li class="schema-type-row" data-harness="type-row" data-type-id="${t.id ?? ""}">
            <span class="schema-type-name">${t.name ?? t.id ?? "Unknown"}</span>
            <span class="schema-type-meta">.${t.id ?? "?"} · ${props} properties${builtIn}</span>
          </li>
        `;
      })
      .join("");

    note.hidden = false;
    if (page) {
      note.textContent =
        "Page type present — seeded by SchemaStore / ensureSkeleton. " +
        (manifest.note ?? "");
      note.dataset.pagePresent = "true";
    } else {
      note.textContent = "Page type missing from fixtures.";
      note.dataset.pagePresent = "false";
    }
  } catch (err) {
    loading.textContent =
      err instanceof Error ? err.message : "Failed to load demo-schema fixtures";
    note.hidden = false;
    note.textContent = "Run: ./scripts/demo-schema.sh then refresh this panel (?panel=types).";
  }
}

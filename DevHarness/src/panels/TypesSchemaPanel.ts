/**
 * Types / schema + Pages list panel (PR05 + PR08).
 * Loads `/demo-schema/manifest.json` and `/demo-objects/pages.json`
 * (written by scripts/demo-schema.sh and scripts/demo-objects.sh).
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
        Pages are listed from the local index via <code>ObjectService</code> / <code>IndexQuerying</code>.
      </p>
      <section class="vault-card" data-harness="types-status" aria-label="Schema types">
        <p class="vault-kicker">PR05 · SchemaStore</p>
        <h3 class="vault-card-title">Object types</h3>
        <p class="vault-card-body" data-harness="types-loading">Loading demo-schema fixtures…</p>
        <ul class="schema-type-list" data-harness="type-list" hidden></ul>
        <p class="vault-note" data-harness="types-note" hidden></p>
      </section>
      <section class="vault-card" data-harness="pages-status" aria-label="Pages">
        <p class="vault-kicker">PR08 · ObjectService</p>
        <h3 class="vault-card-title">Pages</h3>
        <p class="vault-card-body" data-harness="pages-loading">Loading demo-objects fixture…</p>
        <ul class="schema-type-list" data-harness="page-list" hidden></ul>
        <div class="page-detail" data-harness="page-detail" hidden>
          <p class="vault-kicker">Detail placeholder</p>
          <p class="vault-card-body" data-harness="page-detail-body"></p>
        </div>
        <p class="vault-note" data-harness="pages-note" hidden></p>
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
            <span class="schema-type-name">${escapeHtml(t.name ?? t.id ?? "Unknown")}</span>
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

  await renderPagesSection(root);
}

async function renderPagesSection(root: HTMLElement): Promise<void> {
  const loading = root.querySelector<HTMLElement>("[data-harness='pages-loading']");
  const list = root.querySelector<HTMLUListElement>("[data-harness='page-list']");
  const note = root.querySelector<HTMLElement>("[data-harness='pages-note']");
  const detail = root.querySelector<HTMLElement>("[data-harness='page-detail']");
  const detailBody = root.querySelector<HTMLElement>("[data-harness='page-detail-body']");
  if (!loading || !list || !note || !detail || !detailBody) return;

  try {
    const res = await fetch("/demo-objects/pages.json", { cache: "no-store" });
    if (!res.ok) {
      throw new Error(`HTTP ${res.status} — run ./scripts/demo-objects.sh`);
    }
    const data = (await res.json()) as {
      moduleVersion?: string;
      pageCount?: number;
      indexInsideVault?: boolean;
      pages?: Array<{
        id?: string;
        type?: string;
        title?: string;
        relativePath?: string;
        tags?: string[];
      }>;
      openedSample?: {
        id?: string;
        title?: string;
        relativePath?: string;
        bodyPreview?: string;
      };
      note?: string;
    };

    const pages = data.pages ?? [];
    loading.textContent = `${pages.length} page(s) from ObjectService · indexInsideVault=${
      data.indexInsideVault ?? "?"
    } · ${data.moduleVersion ?? ""}`;

    list.hidden = false;
    list.innerHTML = pages
      .map(
        (p) => `
        <li class="schema-type-row" data-harness="page-row" data-object-id="${escapeHtml(
          p.id ?? "",
        )}" role="button" tabindex="0">
          <span class="schema-type-name">${escapeHtml(p.title ?? "Untitled")}</span>
          <span class="schema-type-meta">${escapeHtml(p.relativePath ?? "")}</span>
        </li>`,
      )
      .join("");

    list.querySelectorAll<HTMLLIElement>("[data-harness='page-row']").forEach((row) => {
      const show = () => {
        const id = row.dataset.objectId ?? "";
        const page = pages.find((p) => p.id === id);
        detail.hidden = false;
        detailBody.textContent = page
          ? `Open placeholder — ${page.title ?? "Untitled"} (${page.relativePath ?? ""})\nFull ObjectEditor is Apple SwiftUI; BlockEditor lands in PR09.`
          : "Unknown page";
        detail.dataset.objectId = id;
      };
      row.addEventListener("click", show);
      row.addEventListener("keydown", (ev) => {
        if (ev.key === "Enter" || ev.key === " ") {
          ev.preventDefault();
          show();
        }
      });
    });

    note.hidden = false;
    note.textContent =
      data.note ??
      "Create → index → list via ObjectService. Run ./scripts/demo-objects.sh to refresh.";
    note.dataset.indexInsideVault = String(data.indexInsideVault === true);
    if (data.openedSample?.bodyPreview) {
      note.textContent += ` Opened sample body: “${data.openedSample.bodyPreview}”`;
    }
  } catch (err) {
    loading.textContent =
      err instanceof Error ? err.message : "Failed to load demo-objects fixture";
    note.hidden = false;
    note.textContent = "Run: ./scripts/demo-objects.sh then refresh (?panel=types).";
  }
}

function escapeHtml(value: string): string {
  return value
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;");
}

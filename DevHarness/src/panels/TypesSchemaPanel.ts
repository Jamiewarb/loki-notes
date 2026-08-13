/**
 * Types / schema + custom type dashboard (PR05 + PR08 + PR12).
 * Loads `/demo-schema/manifest.json`, `/demo-types/types.json`, `/demo-objects/pages.json`.
 */
export async function renderTypesSchema(root: HTMLElement): Promise<void> {
  root.innerHTML = `
    <div class="destination types-schema" data-harness="destination" data-destination="types">
      <header class="destination-header">
        <span class="destination-icon" aria-hidden="true">▦</span>
        <h2 class="destination-title">Types</h2>
      </header>
      <p class="destination-lead">
        Create custom types on the fly — <code>.loci/types/&lt;slug&gt;.json</code> +
        <code>objects/&lt;slug&gt;/</code>. Built-in Page/Daily are protected from casual delete.
        Type dashboards list All objects, manual <strong>collection tabs</strong>, and
        <strong>pinned queries</strong> (defs in <code>.loci/queries/&lt;slug&gt;.json</code>;
        results live from the index).
      </p>
      <section class="vault-card" data-harness="types-status" aria-label="Schema types">
        <p class="vault-kicker">PR15 · SchemaServing + PARA + templates</p>
        <h3 class="vault-card-title">Object types</h3>
        <p class="vault-card-body" data-harness="types-loading">Loading demo fixtures…</p>
        <ul class="schema-type-list" data-harness="type-list" hidden></ul>
        <p class="vault-note" data-harness="types-note" hidden></p>
      </section>
      <section class="vault-card" data-harness="para-dashboard" aria-label="PARA Project Area">
        <p class="vault-kicker">PR15 · PARA starter pack</p>
        <h3 class="vault-card-title">Project · Area</h3>
        <p class="vault-card-body" data-harness="para-types-loading">Loading demo-para / demo-types…</p>
        <ul class="schema-type-list" data-harness="para-types-list" hidden></ul>
        <p class="vault-note" data-harness="para-types-note" hidden></p>
      </section>
      <section class="vault-card" data-harness="books-dashboard" aria-label="Books dashboard">
        <p class="vault-kicker">PR22 · Type dashboard + collections</p>
        <h3 class="vault-card-title">Books</h3>
        <p class="vault-card-body" data-harness="books-loading">Loading demo-types fixture…</p>
        <div class="collection-tabs" data-harness="collection-tabs" hidden></div>
        <ul class="schema-type-list" data-harness="books-list" hidden></ul>
        <div class="page-detail" data-harness="books-recent" hidden>
          <p class="vault-kicker">Recently opened</p>
          <p class="vault-card-body">Stub — session recents land later. Use All for now.</p>
        </div>
        <p class="vault-note" data-harness="books-note" hidden></p>
      </section>
      <section class="vault-card" data-harness="collections-status" aria-label="Collections">
        <p class="vault-kicker">PR22 · Manual collections</p>
        <h3 class="vault-card-title">Collections</h3>
        <p class="vault-card-body" data-harness="collections-loading">Loading demo-collections…</p>
        <ul class="schema-type-list" data-harness="collections-list" hidden></ul>
        <pre class="md-pre" data-harness="collections-snippet" style="max-height:10rem;overflow:auto" hidden></pre>
        <p class="vault-note" data-harness="collections-note" hidden></p>
      </section>
      <section class="vault-card" data-harness="queries-status" aria-label="Saved queries">
        <p class="vault-kicker">PR23 · Saved queries + embeds</p>
        <h3 class="vault-card-title">Pinned queries</h3>
        <p class="vault-card-body" data-harness="queries-loading">Loading demo-queries…</p>
        <div class="collection-tabs" data-harness="pinned-query-tabs" hidden></div>
        <ul class="schema-type-list" data-harness="queries-results" hidden></ul>
        <pre class="md-pre" data-harness="queries-snippet" style="max-height:10rem;overflow:auto" hidden></pre>
        <p class="vault-note" data-harness="queries-note" hidden></p>
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

  await renderTypesSection(root);
  await renderPARASection(root);
  await renderBooksDashboard(root);
  await renderCollectionsSection(root);
  await renderQueriesSection(root);
  await renderPagesSection(root);
}

async function renderPARASection(root: HTMLElement): Promise<void> {
  const loading = root.querySelector<HTMLElement>("[data-harness='para-types-loading']");
  const list = root.querySelector<HTMLUListElement>("[data-harness='para-types-list']");
  const note = root.querySelector<HTMLElement>("[data-harness='para-types-note']");
  if (!loading || !list || !note) return;

  try {
    let data: {
      projectObject?: { title?: string; bodyMarkdown?: string; prefilled?: boolean };
      areaObject?: { title?: string; bodyMarkdown?: string; prefilled?: boolean };
      projectTemplate?: { id?: string; bodyPreview?: string };
      areaTemplate?: { id?: string; bodyPreview?: string };
      archiveFilter?: { archivedHidden?: number; visibleWhenHideArchived?: number };
      para?: {
        explainer?: string;
        resourceApproach?: string;
        archiveApproach?: string;
        idempotent?: boolean;
        resourceTypeExists?: boolean;
      };
      types?: Array<{ id?: string; name?: string; defaultTemplateID?: string }>;
      note?: string;
    } | null = null;

    const typesRes = await fetch("/demo-types/types.json", { cache: "no-store" });
    if (typesRes.ok) {
      data = (await typesRes.json()) as typeof data;
    }
    if (!data?.projectTemplate) {
      const paraRes = await fetch("/demo-para/para.json", { cache: "no-store" });
      if (paraRes.ok) {
        data = (await paraRes.json()) as typeof data;
      }
    }
    if (!data) throw new Error("missing PARA fixtures");

    const project = (data.types ?? []).find((t) => t.id === "project");
    const area = (data.types ?? []).find((t) => t.id === "area");
    loading.textContent = `PARA · Project ${project?.defaultTemplateID ?? data.projectTemplate?.id ?? "?"} · Area ${
      area?.defaultTemplateID ?? data.areaTemplate?.id ?? "?"
    }`;
    list.hidden = false;
    list.innerHTML = `
      <li class="schema-type-row" data-harness="para-project-row">
        <span class="schema-type-name">${escapeHtml(data.projectObject?.title ?? "Project")}</span>
        <span class="schema-type-meta">${escapeHtml(
          data.projectObject?.prefilled
            ? "template prefill ✓"
            : (data.projectTemplate?.bodyPreview ?? "").split("\n")[0] || "project",
        )}</span>
      </li>
      <li class="schema-type-row" data-harness="para-area-row">
        <span class="schema-type-name">${escapeHtml(data.areaObject?.title ?? "Area")}</span>
        <span class="schema-type-meta">${escapeHtml(
          data.areaObject?.prefilled
            ? "template prefill ✓"
            : (data.areaTemplate?.bodyPreview ?? "").split("\n")[0] || "area",
        )}</span>
      </li>
    `;
    note.hidden = false;
    const filt = data.archiveFilter;
    note.textContent = [
      data.para?.resourceApproach ?? "tag:#resource",
      data.para?.archiveApproach ?? "tag:#archive",
      data.para?.resourceTypeExists === false ? "no Resource type" : null,
      filt
        ? `hide archived: ${filt.archivedHidden ?? 0} hidden / ${filt.visibleWhenHideArchived ?? 0} visible`
        : null,
      data.para?.idempotent ? "idempotent ✓" : null,
    ]
      .filter(Boolean)
      .join(" · ");
  } catch {
    loading.textContent = "Run ./scripts/demo-para.sh for Project/Area fixtures.";
  }
}

async function renderTypesSection(root: HTMLElement): Promise<void> {
  const loading = root.querySelector<HTMLElement>("[data-harness='types-loading']");
  const list = root.querySelector<HTMLUListElement>("[data-harness='type-list']");
  const note = root.querySelector<HTMLElement>("[data-harness='types-note']");
  if (!loading || !list || !note) return;

  try {
    // Prefer PR13 demo-properties / demo-types; fall back to demo-schema manifest.
    let manifest: {
      space?: { name?: string; schemaVersion?: number };
      types?: Array<{
        id?: string;
        name?: string;
        icon?: string;
        color?: string;
        isBuiltIn?: boolean;
        properties?: Array<{ id?: string; name?: string; kind?: string }>;
      }>;
      note?: string;
      pageDeleteBlocked?: boolean;
      appearsOnlyUnderBooks?: boolean;
      survivedReload?: boolean;
    } | null = null;

    const typesRes = await fetch("/demo-types/types.json", { cache: "no-store" });
    if (typesRes.ok) {
      const data = (await typesRes.json()) as typeof manifest & {
        pageDeleteBlocked?: boolean;
        appearsOnlyUnderBooks?: boolean;
        survivedReload?: boolean;
      };
      manifest = data;
    } else {
      const res = await fetch("/demo-schema/manifest.json", { cache: "no-store" });
      if (!res.ok) {
        throw new Error(
          `HTTP ${res.status} — run ./scripts/demo-properties.sh (or demo-types.sh)`,
        );
      }
      manifest = (await res.json()) as typeof manifest;
    }

    const types = manifest?.types ?? [];
    const page = types.find((t) => t.id === "page");
    const book = types.find((t) => t.id === "book");
    loading.textContent = `Space “${manifest?.space?.name ?? "Loci"}” · ${types.length} type(s)`;

    list.hidden = false;
    list.innerHTML = types
      .map((t) => {
        const props = Array.isArray(t.properties) ? t.properties : [];
        const propLabel =
          props.length === 0
            ? "0 properties"
            : `${props.length} properties (${props
                .map((p) => p.id ?? p.name ?? "?")
                .join(", ")})`;
        const builtIn = t.isBuiltIn ? " · built-in" : "";
        return `
          <li class="schema-type-row" data-harness="type-row" data-type-id="${t.id ?? ""}">
            <span class="schema-type-name">${escapeHtml(t.name ?? t.id ?? "Unknown")}</span>
            <span class="schema-type-meta">.${t.id ?? "?"} · ${propLabel}${builtIn}${
              t.color ? ` · ${escapeHtml(t.color)}` : ""
            }</span>
          </li>
        `;
      })
      .join("");

    note.hidden = false;
    const bits: string[] = [];
    if (page) bits.push("Page seeded");
    if (book) bits.push("Books custom type present");
    if ((book?.properties?.length ?? 0) > 0) {
      bits.push(`Book defs: ${(book?.properties ?? []).map((p) => p.id).join(", ")}`);
    }
    if (manifest?.pageDeleteBlocked) bits.push("Page delete guarded ✓");
    if (manifest?.appearsOnlyUnderBooks) bits.push("Deep Work only under Books ✓");
    if (manifest?.survivedReload) bits.push("Properties survive reload ✓");
    if ((book as { defaultTemplateID?: string } | undefined)?.defaultTemplateID) {
      bits.push(`Book default template: ${(book as { defaultTemplateID?: string }).defaultTemplateID}`);
    }
    note.textContent = bits.join(" · ") || (manifest?.note ?? "");
    note.dataset.pagePresent = page ? "true" : "false";
    note.dataset.bookPresent = book ? "true" : "false";
    note.dataset.bookPropCount = String(book?.properties?.length ?? 0);
  } catch (err) {
    loading.textContent =
      err instanceof Error ? err.message : "Failed to load type fixtures";
    note.hidden = false;
    note.textContent = "Run: ./scripts/demo-properties.sh then refresh (?panel=types).";
  }
}

async function renderBooksDashboard(root: HTMLElement): Promise<void> {
  const loading = root.querySelector<HTMLElement>("[data-harness='books-loading']");
  const list = root.querySelector<HTMLUListElement>("[data-harness='books-list']");
  const note = root.querySelector<HTMLElement>("[data-harness='books-note']");
  const recent = root.querySelector<HTMLElement>("[data-harness='books-recent']");
  if (!loading || !list || !note || !recent) return;

  try {
    const res = await fetch("/demo-types/types.json", { cache: "no-store" });
    if (!res.ok) {
      throw new Error(`HTTP ${res.status} — run ./scripts/demo-types.sh`);
    }
    const data = (await res.json()) as {
      bookObject?: {
        id?: string;
        type?: string;
        title?: string;
        relativePath?: string;
        tags?: string[];
        properties?: Record<string, string | number | boolean>;
        bodyMarkdown?: string;
        prefilledHeadings?: boolean;
      };
      books?: Array<{
        id?: string;
        title?: string;
        relativePath?: string;
        inFavorites?: boolean;
        inReadingList?: boolean;
      }>;
      booksCount?: number;
      allBooksCount?: number;
      collectionTabs?: string[];
      favorites?: { id?: string; memberCount?: number; relativePath?: string };
      pagesCount?: number;
      appearsOnlyUnderBooks?: boolean;
      objectsFolder?: string;
      objectsFolderExists?: boolean;
      pageDeleteBlocked?: boolean;
      survivedReload?: boolean;
      statusIndexed?: boolean;
      ratingIndexed?: boolean;
      bookPrefill?: boolean;
      dailyPrefill?: boolean;
      bookTemplate?: { id?: string; name?: string; path?: string; bodyPreview?: string };
      dailyTemplate?: { id?: string; name?: string; path?: string; bodyPreview?: string };
      dailyObject?: { bodyMarkdown?: string; title?: string; relativePath?: string };
      propertiesIdx?: Array<{ key?: string; valueText?: string; valueNumber?: number }>;
      frontmatterSnippet?: string;
      moduleVersion?: string;
      note?: string;
      collectionsNote?: string;
    };

    const book = data.bookObject;
    const booksFromCollections = data.books ?? [];
    const booksCount = data.booksCount ?? data.allBooksCount ?? booksFromCollections.length;
    loading.textContent = `All · ${booksCount} book(s) · folder ${
      data.objectsFolder ?? "objects/book"
    } exists=${data.objectsFolderExists ?? "?"} · ${data.moduleVersion ?? ""}`;

    list.hidden = false;
    if (booksFromCollections.length > 0) {
      list.innerHTML = booksFromCollections
        .map(
          (b) => `
        <li class="schema-type-row">
          <span class="schema-type-name">${escapeHtml(b.title ?? "Untitled")}</span>
          <span class="schema-type-meta">${escapeHtml(b.relativePath ?? "")}${
            b.inFavorites ? " · ★ Favorites" : ""
          }</span>
        </li>`,
        )
        .join("");
    } else if (book) {
      const propBits = Object.entries(book.properties ?? {})
        .map(([k, v]) => `${k}=${v}`)
        .join(" · ");
      list.innerHTML = `
        <li class="schema-type-row" data-harness="book-row" data-object-id="${escapeHtml(
          book.id ?? "",
        )}" role="button" tabindex="0">
          <span class="schema-type-name">${escapeHtml(book.title ?? "Untitled")}</span>
          <span class="schema-type-meta">${escapeHtml(
            propBits || book.relativePath || "",
          )}</span>
        </li>`;
    } else {
      list.innerHTML = `<li class="schema-type-row"><span class="schema-type-meta">No books yet</span></li>`;
    }

    // Object detail — properties survive reload (PR13).
    let detail = root.querySelector<HTMLElement>("[data-harness='book-detail']");
    if (!detail) {
      detail = document.createElement("div");
      detail.className = "page-detail";
      detail.dataset.harness = "book-detail";
      detail.hidden = true;
      recent.insertAdjacentElement("beforebegin", detail);
    }
    if (book) {
      const props = book.properties ?? {};
      const propRows = Object.entries(props)
        .map(
          ([k, v]) =>
            `<div><dt>${escapeHtml(k)}</dt><dd data-harness="prop-${escapeHtml(k)}">${escapeHtml(
              String(v),
            )}</dd></div>`,
        )
        .join("");
      detail.hidden = false;
      detail.innerHTML = `
        <p class="vault-kicker">PR14 · Templates + properties</p>
        <p class="vault-card-body" data-harness="book-detail-title">${escapeHtml(
          book.title ?? "Untitled",
        )} · ${escapeHtml(book.relativePath ?? "")}</p>
        <dl class="vault-meta" data-harness="book-properties">${
          propRows || "<div><dt>—</dt><dd>none</dd></div>"
        }</dl>
        <p class="vault-note" data-harness="book-template-proof">
          bookPrefill=${data.bookPrefill === true ? "yes" : "no"} ·
          dailyPrefill=${data.dailyPrefill === true ? "yes" : "no"} ·
          template=${escapeHtml(data.bookTemplate?.id ?? "?")} ·
          survivedReload=${data.survivedReload === true ? "yes" : "no"}
        </p>
        ${
          book.bodyMarkdown
            ? `<pre class="md-pre" data-harness="book-body" style="max-height:10rem;overflow:auto">${escapeHtml(
                book.bodyMarkdown,
              )}</pre>`
            : ""
        }
        ${
          data.dailyObject?.bodyMarkdown
            ? `<p class="vault-kicker">Daily template body</p><pre class="md-pre" data-harness="daily-body" style="max-height:8rem;overflow:auto">${escapeHtml(
                data.dailyObject.bodyMarkdown,
              )}</pre>`
            : ""
        }
        ${
          data.frontmatterSnippet
            ? `<pre class="md-pre" data-harness="book-frontmatter" style="max-height:12rem;overflow:auto">${escapeHtml(
                data.frontmatterSnippet,
              )}</pre>`
            : ""
        }
      `;
    }

    recent.hidden = false;
    note.hidden = false;
    note.textContent =
      data.note ??
      "Default Book template prefills headings; new daily uses daily template (PR14).";
    note.dataset.appearsOnlyUnderBooks = String(data.appearsOnlyUnderBooks === true);
    note.dataset.pageDeleteBlocked = String(data.pageDeleteBlocked === true);
    note.dataset.survivedReload = String(data.survivedReload === true);
    note.dataset.bookPrefill = String(data.bookPrefill === true);
    note.dataset.dailyPrefill = String(data.dailyPrefill === true);
  } catch (err) {
    loading.textContent =
      err instanceof Error ? err.message : "Failed to load demo-types fixture";
    note.hidden = false;
    note.textContent = "Run: ./scripts/demo-types.sh then refresh (?panel=types).";
  }
}

async function renderCollectionsSection(root: HTMLElement): Promise<void> {
  const loading = root.querySelector<HTMLElement>("[data-harness='collections-loading']");
  const list = root.querySelector<HTMLUListElement>("[data-harness='collections-list']");
  const note = root.querySelector<HTMLElement>("[data-harness='collections-note']");
  const snippet = root.querySelector<HTMLElement>("[data-harness='collections-snippet']");
  const tabs = root.querySelector<HTMLElement>("[data-harness='collection-tabs']");
  const booksList = root.querySelector<HTMLUListElement>("[data-harness='books-list']");
  if (!loading || !list || !note) return;

  try {
    let data: {
      collections?: Array<{
        id?: string;
        name?: string;
        memberCount?: number;
        memberIDs?: string[];
        relativePath?: string;
      }>;
      favorites?: {
        id?: string;
        name?: string;
        memberCount?: number;
        memberTitles?: string[];
        relativePath?: string;
        exists?: boolean;
      };
      readingList?: { id?: string; name?: string; memberCount?: number };
      tabs?: string[];
      books?: Array<{
        id?: string;
        title?: string;
        relativePath?: string;
        inFavorites?: boolean;
        inReadingList?: boolean;
      }>;
      allBooksCount?: number;
      membershipIsVaultFile?: boolean;
      collectionsDirectory?: string;
      vaultFileSnippet?: string;
      moduleVersion?: string;
      note?: string;
    } | null = null;

    const colRes = await fetch("/demo-collections/collections.json", { cache: "no-store" });
    if (colRes.ok) {
      data = (await colRes.json()) as typeof data;
    } else {
      const typesRes = await fetch("/demo-types/types.json", { cache: "no-store" });
      if (typesRes.ok) {
        data = (await typesRes.json()) as typeof data;
      }
    }
    if (!data?.favorites) throw new Error("missing collections fixtures");

    const fav = data.favorites;
    loading.textContent = `Vault membership · ${fav.relativePath ?? ".loci/collections/…"} · ${
      data.moduleVersion ?? ""
    }`;

    list.hidden = false;
    list.innerHTML = (data.collections ?? [])
      .map(
        (c) => `
        <li class="schema-type-row" data-harness="collection-row" data-collection-id="${escapeHtml(
          c.id ?? "",
        )}">
          <span class="schema-type-name">${escapeHtml(c.name ?? c.id ?? "?")}</span>
          <span class="schema-type-meta">${escapeHtml(c.id ?? "")} · ${
            c.memberCount ?? 0
          } members · ${escapeHtml(c.relativePath ?? "")}</span>
        </li>`,
      )
      .join("");

    if (tabs) {
      tabs.hidden = false;
      const tabNames = data.tabs ?? ["All", "Favorites"];
      tabs.innerHTML = tabNames
        .map(
          (name, i) =>
            `<button type="button" class="nav-btn${i === 0 ? " is-active" : ""}" data-collection-tab="${escapeHtml(
              name,
            )}">${escapeHtml(name)}</button>`,
        )
        .join(" ");
      tabs.querySelectorAll<HTMLButtonElement>("[data-collection-tab]").forEach((btn) => {
        btn.addEventListener("click", () => {
          tabs.querySelectorAll(".nav-btn").forEach((b) => b.classList.remove("is-active"));
          btn.classList.add("is-active");
          const tab = btn.dataset.collectionTab ?? "All";
          if (!booksList || !data?.books) return;
          const filtered = data.books.filter((b) => {
            if (tab === "All") return true;
            if (tab === "Favorites") return b.inFavorites === true;
            if (tab === "Reading List") return b.inReadingList === true;
            return true;
          });
          booksList.innerHTML = filtered
            .map(
              (b) => `
              <li class="schema-type-row">
                <span class="schema-type-name">${escapeHtml(b.title ?? "Untitled")}</span>
                <span class="schema-type-meta">${escapeHtml(b.relativePath ?? "")}</span>
              </li>`,
            )
            .join("");
        });
      });
    }

    if (snippet && data.vaultFileSnippet) {
      snippet.hidden = false;
      snippet.textContent = data.vaultFileSnippet;
    }

    note.hidden = false;
    note.textContent =
      data.note ??
      `Favorites ${fav.memberCount ?? 0} members · membershipIsVaultFile=${
        data.membershipIsVaultFile === true ? "yes" : "no"
      }`;
    note.dataset.membershipIsVaultFile = String(data.membershipIsVaultFile === true);
    note.dataset.favoritesId = fav.id ?? "";
    note.dataset.favoritesMembers = String(fav.memberCount ?? 0);
  } catch (err) {
    loading.textContent =
      err instanceof Error ? err.message : "Failed to load collections fixtures";
    note.hidden = false;
    note.textContent = "Run: ./scripts/demo-collections.sh then refresh (?panel=types).";
  }
}

async function renderQueriesSection(root: HTMLElement): Promise<void> {
  const loading = root.querySelector<HTMLElement>("[data-harness='queries-loading']");
  const results = root.querySelector<HTMLUListElement>("[data-harness='queries-results']");
  const note = root.querySelector<HTMLElement>("[data-harness='queries-note']");
  const snippet = root.querySelector<HTMLElement>("[data-harness='queries-snippet']");
  const tabs = root.querySelector<HTMLElement>("[data-harness='pinned-query-tabs']");
  if (!loading || !results || !note) return;

  try {
    let data: {
      query?: {
        id?: string;
        name?: string;
        relativePath?: string;
        exists?: boolean;
        definitionOnly?: boolean;
        pinnedTypeID?: string;
        tags?: string[];
        propertyEquals?: string;
      };
      resultTitles?: string[];
      resultCount?: number;
      results?: Array<{ id?: string; title?: string; tags?: string[] }>;
      pinnedQueryIDs?: string[];
      queriesDirectory?: string;
      definitionIsVaultFile?: boolean;
      vaultFileSnippet?: string;
      moduleVersion?: string;
      note?: string;
      embed?: { storesResultsInBody?: boolean; roundTripKind?: string };
    } | null = null;

    const qRes = await fetch("/demo-queries/queries.json", { cache: "no-store" });
    if (qRes.ok) {
      data = (await qRes.json()) as typeof data;
    } else {
      const typesRes = await fetch("/demo-types/types.json", { cache: "no-store" });
      if (typesRes.ok) {
        const t = (await typesRes.json()) as {
          queries?: Array<typeof data extends null ? never : NonNullable<typeof data>["query"]>;
          queryResultTitles?: string[];
          queryResultCount?: number;
          queryResults?: Array<{ id?: string; title?: string; tags?: string[] }>;
          pinnedQueries?: string[];
          queriesDirectory?: string;
          definitionIsVaultFile?: boolean;
          moduleVersion?: string;
          queriesNote?: string;
        };
        data = {
          query: t.queries?.[0],
          resultTitles: t.queryResultTitles,
          resultCount: t.queryResultCount,
          results: t.queryResults,
          pinnedQueryIDs: t.pinnedQueries,
          queriesDirectory: t.queriesDirectory,
          definitionIsVaultFile: t.definitionIsVaultFile,
          moduleVersion: t.moduleVersion,
          note: t.queriesNote,
        };
      }
    }
    if (!data?.query?.id) throw new Error("missing queries fixtures");

    const q = data.query;
    loading.textContent = `Pinned · ${q.relativePath ?? ".loci/queries/…"} · ${
      data.resultCount ?? 0
    } live hits · ${data.moduleVersion ?? ""}`;

    if (tabs) {
      tabs.hidden = false;
      tabs.innerHTML = `<button type="button" class="nav-btn is-active" data-harness="pinned-query-chip">${escapeHtml(
        q.name ?? q.id ?? "Query",
      )}</button>`;
    }

    results.hidden = false;
    const titles = data.resultTitles ?? (data.results ?? []).map((r) => r.title ?? "");
    results.innerHTML = titles
      .map(
        (title) => `
        <li class="schema-type-row" data-harness="query-result-row">
          <span class="schema-type-name">${escapeHtml(title || "Untitled")}</span>
          <span class="schema-type-meta">live index hit</span>
        </li>`,
      )
      .join("");

    if (snippet && data.vaultFileSnippet) {
      snippet.hidden = false;
      snippet.textContent = data.vaultFileSnippet;
    }

    note.hidden = false;
    note.textContent =
      data.note ??
      `definitionOnly=${q.definitionOnly === true ? "yes" : "no"} · embed stores results=${
        data.embed?.storesResultsInBody === true ? "yes" : "no"
      } · definitionIsVaultFile=${data.definitionIsVaultFile === true ? "yes" : "no"}`;
    note.dataset.queryId = q.id ?? "";
    note.dataset.resultCount = String(data.resultCount ?? 0);
    note.dataset.definitionIsVaultFile = String(data.definitionIsVaultFile === true);
  } catch (err) {
    loading.textContent =
      err instanceof Error ? err.message : "Failed to load queries fixtures";
    note.hidden = false;
    note.textContent = "Run: ./scripts/demo-queries.sh then refresh (?panel=types).";
  }
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
          ? `Open placeholder — ${page.title ?? "Untitled"} (${page.relativePath ?? ""})`
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

/**
 * Graph panel — force-directed wiki-link network from links table (PR24).
 * Loads `/demo-graph/graph.json` from `scripts/demo-graph.sh`.
 */
export async function renderGraphPanel(root: HTMLElement): Promise<void> {
  root.innerHTML = `
    <div class="destination graph-panel" data-harness="destination" data-destination="graph">
      <header class="destination-header">
        <span class="destination-icon" aria-hidden="true">⬡</span>
        <h2 class="destination-title">Graph</h2>
      </header>
      <p class="destination-lead">
        Wiki-link network from <code>IndexQuerying.graph</code> · type filter · node/edge caps.
      </p>
      <p class="vault-note" data-harness="graph-status">Loading graph demo…</p>
    </div>
  `;

  const status = root.querySelector("[data-harness='graph-status']");
  try {
    const res = await fetch("/demo-graph/graph.json", { cache: "no-store" });
    if (!res.ok) throw new Error(`HTTP ${res.status}`);
    const data = (await res.json()) as {
      moduleVersion: string;
      indexModuleVersion?: string;
      indexInsideVault: boolean;
      layout: { width: number; height: number };
      graph: {
        nodeCount: number;
        edgeCount: number;
        truncated: boolean;
        unresolvedLinkCount: number;
        nodes: Array<{ id: string; title: string; type: string; x: number; y: number }>;
        edges: Array<{ from: string; to: string; label?: string }>;
      };
      booksFilter: { type: string; nodeCount: number; edgeCount: number; titles: string[] };
      capProof: { maxNodes: number; maxEdges: number; nodeCount: number; edgeCount: number; truncated: boolean };
      proof: Record<string, boolean>;
      note: string;
    };

    const g = data.graph;
    const w = data.layout?.width ?? 720;
    const h = data.layout?.height ?? 480;
    const byId = new Map(g.nodes.map((n) => [n.id, n]));

    const edgesSvg = g.edges
      .map((e) => {
        const a = byId.get(e.from);
        const b = byId.get(e.to);
        if (!a || !b) return "";
        return `<line x1="${a.x}" y1="${a.y}" x2="${b.x}" y2="${b.y}" class="graph-edge" />`;
      })
      .join("");

    const nodesSvg = g.nodes
      .map(
        (n) => `
        <g class="graph-node" data-harness="graph-node" data-object-id="${escapeAttr(n.id)}" data-type="${escapeAttr(n.type)}" role="button" tabindex="0">
          <circle cx="${n.x}" cy="${n.y}" r="12" />
          <text x="${n.x}" y="${n.y + 24}" text-anchor="middle">${escapeAttr(n.title)}</text>
        </g>`,
      )
      .join("");

    root.innerHTML = `
      <div class="destination graph-panel" data-harness="destination" data-destination="graph">
        <header class="destination-header">
          <span class="destination-icon" aria-hidden="true">⬡</span>
          <h2 class="destination-title">Graph</h2>
        </header>
        <p class="destination-lead">
          Deterministic force layout from the local links index
          (${escapeAttr(data.moduleVersion)} / ${escapeAttr(data.indexModuleVersion ?? "")}).
        </p>

        <section class="vault-card" data-harness="graph-proof" aria-label="Graph proof">
          <p class="vault-kicker">PR24 · links table → nodes/edges</p>
          <h3 class="vault-card-title">Wiki-link network</h3>
          <dl class="vault-meta">
            <div>
              <dt>Nodes</dt>
              <dd data-harness="graph-node-count">${g.nodeCount}</dd>
            </div>
            <div>
              <dt>Edges</dt>
              <dd data-harness="graph-edge-count">${g.edgeCount}</dd>
            </div>
            <div>
              <dt>Unresolved</dt>
              <dd data-harness="graph-unresolved">${g.unresolvedLinkCount}</dd>
            </div>
            <div>
              <dt>Books filter</dt>
              <dd data-harness="graph-books-filter">${data.booksFilter.nodeCount} / ${data.booksFilter.edgeCount}</dd>
            </div>
            <div>
              <dt>Cap proof</dt>
              <dd data-harness="graph-cap">${data.capProof.nodeCount}/${data.capProof.edgeCount} truncated=${data.capProof.truncated ? "yes" : "no"}</dd>
            </div>
            <div>
              <dt>Index in vault</dt>
              <dd>${data.indexInsideVault ? "YES (bad)" : "no ✓"}</dd>
            </div>
          </dl>
        </section>

        <section class="graph-canvas-wrap" aria-label="Graph canvas">
          <svg
            class="graph-svg"
            data-harness="graph-svg"
            viewBox="0 0 ${w} ${h}"
            width="100%"
            height="420"
            role="img"
            aria-label="Link graph"
          >
            ${edgesSvg}
            ${nodesSvg}
          </svg>
          <p class="vault-note" data-harness="graph-selection">Click a node — Navigating.open in the app.</p>
        </section>

        <section class="vault-card" aria-label="Type filter">
          <p class="vault-kicker">Type filter · book</p>
          <h3 class="vault-card-title">${escapeAttr((data.booksFilter.titles || []).join(" · ") || "Books")}</h3>
          <p class="vault-card-body">Only book↔book edges survive the type filter.</p>
        </section>

        <p class="vault-note">${escapeAttr(data.note)}</p>
      </div>
    `;

    const selection = root.querySelector<HTMLElement>("[data-harness='graph-selection']");
    root.querySelectorAll<SVGGElement>("[data-harness='graph-node']").forEach((node) => {
      const activate = () => {
        const id = node.getAttribute("data-object-id") ?? "";
        const title = node.querySelector("text")?.textContent ?? id;
        root.querySelectorAll(".graph-node.is-selected").forEach((n) => n.classList.remove("is-selected"));
        node.classList.add("is-selected");
        if (selection) {
          selection.textContent = `Open ${title} → Navigating.open(objectID: ${id})`;
        }
      };
      node.addEventListener("click", activate);
      node.addEventListener("keydown", (ev) => {
        if (ev.key === "Enter" || ev.key === " ") {
          ev.preventDefault();
          activate();
        }
      });
    });
  } catch (err) {
    if (status) {
      status.innerHTML = `Missing graph fixture. Run <code>./scripts/demo-graph.sh</code>. (${escapeAttr(
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

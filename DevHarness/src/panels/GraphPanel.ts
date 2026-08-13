/**
 * Graph panel — force-directed wiki-link network (PR24) + hide hubs / focus (PR45).
 * Loads `/demo-graph/graph.json` from `scripts/demo-graph.sh`.
 */

type GraphNodeFix = {
  id: string;
  title: string;
  type: string;
  degree?: number;
  neighborCount?: number;
  x: number;
  y: number;
};

type GraphEdgeFix = { from: string; to: string; label?: string };

type GraphFix = {
  nodeCount: number;
  edgeCount: number;
  truncated: boolean;
  hiddenHubs?: boolean;
  isolatedFocus?: boolean;
  unresolvedLinkCount?: number;
  nodes: GraphNodeFix[];
  edges: GraphEdgeFix[];
};

type GraphDemo = {
  moduleVersion: string;
  indexModuleVersion?: string;
  indexInsideVault: boolean;
  layoutNotWrittenToVault?: boolean;
  layout: { width: number; height: number };
  graph: GraphFix;
  booksFilter: { type: string; nodeCount: number; edgeCount: number; titles: string[] };
  capProof: {
    maxNodes: number;
    maxEdges: number;
    nodeCount: number;
    edgeCount: number;
    truncated: boolean;
  };
  hideHubs?: GraphFix & { threshold: number; titles: string[] };
  focusNeighbors?: GraphFix & { focusId: string; focusTitle: string; titles: string[] };
  proof: Record<string, boolean>;
  note: string;
};

type GraphMode = "full" | "hide" | "focus";

const GRAPH_SELECT_EVENT = "loci-graph-select";

export async function renderGraphPanel(root: HTMLElement): Promise<void> {
  root.innerHTML = `
    <div class="destination graph-panel" data-harness="destination" data-destination="graph">
      <header class="destination-header">
        <span class="destination-icon" aria-hidden="true">⬡</span>
        <h2 class="destination-title">Graph</h2>
      </header>
      <p class="destination-lead">
        Wiki-link network from <code>IndexQuerying.graph</code> · type filter · hide hubs · focus neighbors.
      </p>
      <p class="vault-note" data-harness="graph-status">Loading graph demo…</p>
    </div>
  `;

  const status = root.querySelector("[data-harness='graph-status']");
  try {
    const res = await fetch("/demo-graph/graph.json", { cache: "no-store" });
    if (!res.ok) throw new Error(`HTTP ${res.status}`);
    const data = (await res.json()) as GraphDemo;
    let mode: GraphMode = "full";
    let selectedId = "";

    const paint = () => {
      const snapshot =
        mode === "hide" && data.hideHubs
          ? data.hideHubs
          : mode === "focus" && data.focusNeighbors
            ? data.focusNeighbors
            : data.graph;
      const w = data.layout?.width ?? 720;
      const h = data.layout?.height ?? 480;
      const byId = new Map(snapshot.nodes.map((n) => [n.id, n]));
      const selected = byId.get(selectedId);

      const edgesSvg = snapshot.edges
        .map((e) => {
          const a = byId.get(e.from);
          const b = byId.get(e.to);
          if (!a || !b) return "";
          const incident = selectedId !== "" && (e.from === selectedId || e.to === selectedId);
          return `<line x1="${a.x}" y1="${a.y}" x2="${b.x}" y2="${b.y}" class="graph-edge${
            incident ? " is-incident" : ""
          }" />`;
        })
        .join("");

      const nodesSvg = snapshot.nodes
        .map(
          (n) => `
        <g class="graph-node${n.id === selectedId ? " is-selected" : ""}" data-harness="graph-node" data-object-id="${escapeAttr(
          n.id,
        )}" data-type="${escapeAttr(n.type)}" role="button" tabindex="0">
          <circle cx="${n.x}" cy="${n.y}" r="${n.id === selectedId ? 14 : 12}" />
          <text x="${n.x}" y="${n.y + 24}" text-anchor="middle">${escapeAttr(n.title)}</text>
        </g>`,
        )
        .join("");

      const flag = (on: boolean | undefined) => (on ? "yes ✓" : "no");
      const proof = data.proof ?? {};

      root.innerHTML = `
      <div class="destination graph-panel" data-harness="destination" data-destination="graph">
        <header class="destination-header">
          <span class="destination-icon" aria-hidden="true">⬡</span>
          <h2 class="destination-title">Graph</h2>
        </header>
        <p class="destination-lead">
          Deterministic force layout from the local links index. Hide hubs and focus are session-only.
        </p>

        <section class="vault-card" data-harness="graph-proof" aria-label="Graph proof">
          <p class="vault-kicker">PR45 · hide hubs · 1-hop focus</p>
          <h3 class="vault-card-title">Wiki-link network</h3>
          <dl class="vault-meta">
            <div>
              <dt>Nodes</dt>
              <dd data-harness="graph-node-count">${snapshot.nodeCount}</dd>
            </div>
            <div>
              <dt>Edges</dt>
              <dd data-harness="graph-edge-count">${snapshot.edgeCount}</dd>
            </div>
            <div>
              <dt>Unresolved</dt>
              <dd data-harness="graph-unresolved">${data.graph.unresolvedLinkCount ?? 0}</dd>
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
              <dt>Hide hubs</dt>
              <dd data-harness="graph-proof-hidesHighDegree">${flag(proof.hidesHighDegree)}</dd>
            </div>
            <div>
              <dt>Focus neighbors</dt>
              <dd data-harness="graph-proof-focusNeighbors">${flag(proof.focusNeighbors)}</dd>
            </div>
            <div>
              <dt>Layout in vault</dt>
              <dd data-harness="graph-proof-layoutNotWrittenToVault">${flag(proof.layoutNotWrittenToVault)}</dd>
            </div>
            <div>
              <dt>Index in vault</dt>
              <dd data-harness="graph-proof-indexInsideVault">${data.indexInsideVault ? "YES (bad)" : "no ✓"}</dd>
            </div>
          </dl>
        </section>

        <p class="graph-controls">
          <button type="button" class="loci-chip${mode === "full" ? " is-selected" : ""}" data-harness="graph-mode-full">All</button>
          <button type="button" class="loci-chip${mode === "hide" ? " is-selected" : ""}" data-harness="graph-hide-hubs">Hide hubs</button>
          <button type="button" class="loci-chip${mode === "focus" ? " is-selected" : ""}" data-harness="graph-focus-neighbors">Focus neighbors</button>
        </p>

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
          <p class="vault-note" data-harness="graph-selection">${
            selected
              ? `Open ${escapeAttr(selected.title)} → Navigating.open(objectID: ${escapeAttr(selected.id)})`
              : "Click a node — Navigating.open in the app."
          }</p>
        </section>

        <section class="vault-card" aria-label="Type filter">
          <p class="vault-kicker">Type filter · book</p>
          <h3 class="vault-card-title">${escapeAttr((data.booksFilter.titles || []).join(" · ") || "Books")}</h3>
          <p class="vault-card-body">Only book↔book edges survive the type filter. Hide hubs / focus never write coordinates into markdown.</p>
        </section>

        <p class="vault-note">${escapeAttr(data.note)}</p>
      </div>
    `;

      window.dispatchEvent(
        new CustomEvent(GRAPH_SELECT_EVENT, {
          detail: {
            selected,
            snapshot,
            proof,
            indexInsideVault: data.indexInsideVault,
            truncated: snapshot.truncated,
            hiddenHubs: snapshot.hiddenHubs === true || mode === "hide",
            isolatedFocus: snapshot.isolatedFocus === true || mode === "focus",
          },
        }),
      );

      root.querySelector("[data-harness='graph-mode-full']")?.addEventListener("click", () => {
        mode = "full";
        paint();
      });
      root.querySelector("[data-harness='graph-hide-hubs']")?.addEventListener("click", () => {
        mode = "hide";
        paint();
      });
      root.querySelector("[data-harness='graph-focus-neighbors']")?.addEventListener("click", () => {
        mode = "focus";
        selectedId = data.focusNeighbors?.focusId || selectedId;
        paint();
      });

      root.querySelectorAll<SVGGElement>("[data-harness='graph-node']").forEach((node) => {
        const activate = () => {
          selectedId = node.getAttribute("data-object-id") ?? "";
          paint();
        };
        node.addEventListener("click", activate);
        node.addEventListener("keydown", (ev) => {
          if (ev.key === "Enter" || ev.key === " ") {
            ev.preventDefault();
            activate();
          }
        });
      });
    };

    paint();
  } catch (err) {
    if (status) {
      status.innerHTML = `Missing graph fixture. Run <code>./scripts/demo-graph.sh</code>. (${escapeAttr(
        String(err),
      )})`;
    }
  }
}

export async function renderGraphInspector(root: HTMLElement): Promise<void> {
  root.innerHTML = `<p data-harness="graph-inspector-loading">Loading graph…</p>`;
  try {
    const res = await fetch("/demo-graph/graph.json", { cache: "no-store" });
    if (!res.ok) throw new Error(`HTTP ${res.status}`);
    const data = (await res.json()) as GraphDemo;
    const proof = data.proof ?? {};
    const paint = (detail?: {
      selected?: GraphNodeFix;
      truncated?: boolean;
      hiddenHubs?: boolean;
      isolatedFocus?: boolean;
    }) => {
      const selected = detail?.selected;
      root.innerHTML = `
        <p class="vault-kicker">Selected node</p>
        <p class="vault-card-title" data-harness="graph-inspector-title">${escapeAttr(
          selected?.title ?? "(none)",
        )}</p>
        <p class="vault-card-body" data-harness="graph-inspector-type">${escapeAttr(
          selected?.type ?? "tap a node",
        )}</p>
        <p class="vault-note" data-harness="graph-inspector-degree">${
          selected
            ? `Degree ${selected.degree ?? "—"} · ${selected.neighborCount ?? "—"} neighbors`
            : "Degree —"
        }</p>
        <ul class="schema-type-list" data-harness="graph-inspector" style="margin-top:0.75rem">
          <li>Truncated · ${detail?.truncated || data.graph.truncated ? "yes" : "no"}</li>
          <li>Hidden hubs · ${detail?.hiddenHubs ? "yes" : "no"}</li>
          <li>Focus neighbors · ${detail?.isolatedFocus ? "yes" : "no"}</li>
          <li>hidesHighDegree · ${proof.hidesHighDegree ? "yes ✓" : "no"}</li>
          <li>layoutNotWrittenToVault · ${proof.layoutNotWrittenToVault ? "yes ✓" : "no"}</li>
          <li>indexInsideVault · ${data.indexInsideVault ? "YES (bad)" : "no ✓"}</li>
        </ul>
        <p class="inspector-hint" style="margin-top:0.75rem">Navigating.open on tap. Session hide/focus — never vault markdown.</p>
      `;
    };
    paint();
    window.addEventListener(GRAPH_SELECT_EVENT, ((ev: Event) => {
      const custom = ev as CustomEvent;
      paint(custom.detail);
    }) as EventListener);
  } catch {
    root.innerHTML = `<p class="inspector-hint">Missing graph fixture. Run <code>./scripts/demo-graph.sh</code>.</p>`;
  }
}

function escapeAttr(value: string): string {
  return value
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;");
}

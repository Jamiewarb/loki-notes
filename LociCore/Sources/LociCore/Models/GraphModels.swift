import Foundation

/// One node in the derived link graph (PR24). Built from the index `links` table — never scraped from markdown in the feature.
public struct GraphNode: Hashable, Sendable, Equatable, Codable, Identifiable {
    public var id: ObjectID
    public var title: String
    public var typeID: ObjectTypeID

    public init(id: ObjectID, title: String, typeID: ObjectTypeID) {
        self.id = id
        self.title = title
        self.typeID = typeID
    }

    public init(meta: LociObjectMeta) {
        self.id = meta.id
        self.title = meta.title
        self.typeID = meta.typeID
    }
}

/// Directed wiki-link edge between two resolved objects.
public struct GraphEdge: Hashable, Sendable, Equatable, Codable, Identifiable {
    public var from: ObjectID
    public var to: ObjectID
    public var label: String?

    public var id: String {
        "\(from.uuidString.lowercased())->\(to.uuidString.lowercased())"
    }

    public init(from: ObjectID, to: ObjectID, label: String? = nil) {
        self.from = from
        self.to = to
        self.label = label
    }
}

/// Caps and filters for graph construction (performance guardrails).
public struct GraphBuildOptions: Hashable, Sendable, Equatable, Codable {
    /// When set, only nodes of this type (and edges between them) are kept.
    public var typeFilter: ObjectTypeID?
    /// Soft cap on nodes after filter (highest-degree first).
    public var maxNodes: Int
    /// Soft cap on edges after filter.
    public var maxEdges: Int
    /// Drop nodes whose degree is ≥ this value **before** caps (nil = off).
    /// Hubs clutter the view; this is the PLAN “hide high-degree nodes” control.
    public var hideDegreeAtOrAbove: Int?
    /// When set, keep this node and its 1-hop neighbors only (isolate).
    public var focusObjectID: ObjectID?

    /// Session UI default for “Hide hubs” (not persisted to vault markdown).
    public static let defaultHideHubDegree = 8

    public static let `default` = GraphBuildOptions()

    public init(
        typeFilter: ObjectTypeID? = nil,
        maxNodes: Int = 150,
        maxEdges: Int = 400,
        hideDegreeAtOrAbove: Int? = nil,
        focusObjectID: ObjectID? = nil
    ) {
        self.typeFilter = typeFilter
        self.maxNodes = max(1, maxNodes)
        self.maxEdges = max(1, maxEdges)
        if let hideDegreeAtOrAbove, hideDegreeAtOrAbove >= 1 {
            self.hideDegreeAtOrAbove = hideDegreeAtOrAbove
        } else {
            self.hideDegreeAtOrAbove = nil
        }
        self.focusObjectID = focusObjectID
    }
}

/// Snapshot of the link graph ready for layout + UI.
public struct GraphSnapshot: Hashable, Sendable, Equatable, Codable {
    public var nodes: [GraphNode]
    public var edges: [GraphEdge]
    /// True when node or edge caps trimmed the full filtered graph.
    public var truncated: Bool
    /// Resolved edges considered before caps (post type-filter / hide / focus).
    public var resolvedEdgeCount: Int
    /// Wiki-link rows skipped because the target did not resolve.
    public var unresolvedLinkCount: Int
    /// True when `hideDegreeAtOrAbove` dropped at least one node.
    public var hiddenHubs: Bool
    /// True when `focusObjectID` isolated the graph to a 1-hop neighborhood.
    public var isolatedFocus: Bool

    public init(
        nodes: [GraphNode] = [],
        edges: [GraphEdge] = [],
        truncated: Bool = false,
        resolvedEdgeCount: Int = 0,
        unresolvedLinkCount: Int = 0,
        hiddenHubs: Bool = false,
        isolatedFocus: Bool = false
    ) {
        self.nodes = nodes
        self.edges = edges
        self.truncated = truncated
        self.resolvedEdgeCount = resolvedEdgeCount
        self.unresolvedLinkCount = unresolvedLinkCount
        self.hiddenHubs = hiddenHubs
        self.isolatedFocus = isolatedFocus
    }

    public var isEmpty: Bool { nodes.isEmpty }

    public func node(id: ObjectID) -> GraphNode? {
        nodes.first { $0.id == id }
    }

    /// Incident edge count (A→B and B→A both count).
    public func degree(of id: ObjectID) -> Int {
        edges.reduce(0) { count, edge in
            count + ((edge.from == id || edge.to == id) ? 1 : 0)
        }
    }

    public func neighborIDs(of id: ObjectID) -> Set<ObjectID> {
        var ids = Set<ObjectID>()
        for edge in edges {
            if edge.from == id { ids.insert(edge.to) }
            if edge.to == id { ids.insert(edge.from) }
        }
        return ids
    }

    public func neighborCount(of id: ObjectID) -> Int {
        neighborIDs(of: id).count
    }

    public func isIncident(_ edge: GraphEdge, to id: ObjectID) -> Bool {
        edge.from == id || edge.to == id
    }
}

/// 2D layout coordinate (pure math — Linux-testable).
public struct GraphPoint: Hashable, Sendable, Equatable, Codable {
    public var x: Double
    public var y: Double

    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }
}

/// Positions keyed by object id string (lowercase UUID).
public struct GraphLayoutResult: Hashable, Sendable, Equatable, Codable {
    public var positions: [String: GraphPoint]
    public var width: Double
    public var height: Double

    public init(positions: [String: GraphPoint] = [:], width: Double = 800, height: Double = 600) {
        self.positions = positions
        self.width = width
        self.height = height
    }

    public func point(for id: ObjectID) -> GraphPoint? {
        positions[id.uuidString.lowercased()]
    }
}

/// Deterministic force-directed layout (fixed iterations, seeded by object id).
///
/// Avoids O(n²) on huge graphs by requiring a pre-capped `GraphSnapshot`.
public enum GraphLayoutEngine: Sendable {
    public struct Config: Hashable, Sendable, Equatable {
        public var width: Double
        public var height: Double
        public var iterations: Int
        public var repulsion: Double
        public var springLength: Double
        public var springStrength: Double
        public var damping: Double
        public var padding: Double

        public static let `default` = Config()

        public init(
            width: Double = 800,
            height: Double = 600,
            iterations: Int = 60,
            repulsion: Double = 2800,
            springLength: Double = 90,
            springStrength: Double = 0.045,
            damping: Double = 0.82,
            padding: Double = 48
        ) {
            self.width = width
            self.height = height
            self.iterations = max(0, iterations)
            self.repulsion = repulsion
            self.springLength = springLength
            self.springStrength = springStrength
            self.damping = damping
            self.padding = padding
        }
    }

    /// Layout nodes into a rectangle. Same input → same positions (no RNG).
    public static func layout(
        _ snapshot: GraphSnapshot,
        config: Config = .default
    ) -> GraphLayoutResult {
        let nodes = snapshot.nodes
        guard !nodes.isEmpty else {
            return GraphLayoutResult(width: config.width, height: config.height)
        }

        let ids = nodes.map { $0.id.uuidString.lowercased() }
        var pos: [String: GraphPoint] = [:]
        var vel: [String: GraphPoint] = [:]

        // Seed on a circle using a stable hash of the id (deterministic).
        let n = Double(nodes.count)
        let cx = config.width / 2
        let cy = config.height / 2
        let radius = min(config.width, config.height) * 0.32
        for (i, id) in ids.enumerated() {
            let angle = (Double(stableHash(id) % 10_000) / 10_000.0) * (Double.pi * 2)
                + (Double(i) / n) * (Double.pi * 2)
            pos[id] = GraphPoint(x: cx + cos(angle) * radius, y: cy + sin(angle) * radius)
            vel[id] = GraphPoint(x: 0, y: 0)
        }

        let edgePairs: [(String, String)] = snapshot.edges.map {
            ($0.from.uuidString.lowercased(), $0.to.uuidString.lowercased())
        }

        if nodes.count == 1, let only = ids.first {
            pos[only] = GraphPoint(x: cx, y: cy)
            return GraphLayoutResult(positions: pos, width: config.width, height: config.height)
        }

        for _ in 0..<config.iterations {
            var forces: [String: GraphPoint] = [:]
            for id in ids {
                forces[id] = GraphPoint(x: 0, y: 0)
            }

            // Repulsion (pairwise — OK because snapshot is capped).
            for i in 0..<ids.count {
                for j in (i + 1)..<ids.count {
                    let a = ids[i]
                    let b = ids[j]
                    guard let pa = pos[a], let pb = pos[b] else { continue }
                    var dx = pa.x - pb.x
                    var dy = pa.y - pb.y
                    var distSq = dx * dx + dy * dy
                    if distSq < 0.01 {
                        distSq = 0.01
                        dx += 0.1
                    }
                    let dist = sqrt(distSq)
                    let force = config.repulsion / distSq
                    let fx = (dx / dist) * force
                    let fy = (dy / dist) * force
                    forces[a] = GraphPoint(x: (forces[a]?.x ?? 0) + fx, y: (forces[a]?.y ?? 0) + fy)
                    forces[b] = GraphPoint(x: (forces[b]?.x ?? 0) - fx, y: (forces[b]?.y ?? 0) - fy)
                }
            }

            // Springs along edges.
            for (from, to) in edgePairs {
                guard let pa = pos[from], let pb = pos[to] else { continue }
                let dx = pb.x - pa.x
                let dy = pb.y - pa.y
                let dist = max(0.01, sqrt(dx * dx + dy * dy))
                let stretch = dist - config.springLength
                let force = stretch * config.springStrength
                let fx = (dx / dist) * force
                let fy = (dy / dist) * force
                forces[from] = GraphPoint(
                    x: (forces[from]?.x ?? 0) + fx,
                    y: (forces[from]?.y ?? 0) + fy
                )
                forces[to] = GraphPoint(
                    x: (forces[to]?.x ?? 0) - fx,
                    y: (forces[to]?.y ?? 0) - fy
                )
            }

            // Mild centering.
            for id in ids {
                guard let p = pos[id] else { continue }
                forces[id] = GraphPoint(
                    x: (forces[id]?.x ?? 0) + (cx - p.x) * 0.008,
                    y: (forces[id]?.y ?? 0) + (cy - p.y) * 0.008
                )
            }

            for id in ids {
                var v = vel[id] ?? GraphPoint(x: 0, y: 0)
                let f = forces[id] ?? GraphPoint(x: 0, y: 0)
                v = GraphPoint(x: (v.x + f.x) * config.damping, y: (v.y + f.y) * config.damping)
                vel[id] = v
                if var p = pos[id] {
                    p.x += v.x
                    p.y += v.y
                    pos[id] = p
                }
            }
        }

        // Fit into padded bounds.
        let xs = pos.values.map(\.x)
        let ys = pos.values.map(\.y)
        let minX = xs.min() ?? 0
        let maxX = xs.max() ?? config.width
        let minY = ys.min() ?? 0
        let maxY = ys.max() ?? config.height
        let spanX = max(1, maxX - minX)
        let spanY = max(1, maxY - minY)
        let availW = max(1, config.width - config.padding * 2)
        let availH = max(1, config.height - config.padding * 2)
        let scale = min(availW / spanX, availH / spanY)

        var fitted: [String: GraphPoint] = [:]
        for (id, p) in pos {
            let nx = (p.x - minX) * scale + config.padding
            let ny = (p.y - minY) * scale + config.padding
            fitted[id] = GraphPoint(x: nx, y: ny)
        }

        return GraphLayoutResult(positions: fitted, width: config.width, height: config.height)
    }

    /// Stable non-cryptographic hash for seeding (same on Linux / Apple).
    public static func stableHash(_ string: String) -> UInt64 {
        var hash: UInt64 = 14695981039346656037
        for byte in string.utf8 {
            hash ^= UInt64(byte)
            hash &*= 1099511628211
        }
        return hash
    }
}

/// Pure graph build helpers (cap / filter) used by Index and unit tests.
public enum GraphAssembly: Sendable {
    /// Apply type filter, hide-hubs, 1-hop focus, then degree-based caps.
    public static func assemble(
        nodesByID: [ObjectID: GraphNode],
        edges: [GraphEdge],
        unresolvedLinkCount: Int,
        options: GraphBuildOptions
    ) -> GraphSnapshot {
        var filteredEdges = edges
        var nodes = nodesByID

        if let typeFilter = options.typeFilter {
            let allowed = Set(nodes.values.filter { $0.typeID == typeFilter }.map(\.id))
            nodes = nodes.filter { allowed.contains($0.key) }
            filteredEdges = filteredEdges.filter {
                allowed.contains($0.from) && allowed.contains($0.to)
            }
        }

        var hiddenHubs = false
        if let threshold = options.hideDegreeAtOrAbove, threshold >= 1 {
            let degree = degreeMap(edges: filteredEdges)
            let drop = Set(
                nodes.keys.filter { id in
                    if id == options.focusObjectID { return false }
                    return degree[id, default: 0] >= threshold
                }
            )
            if !drop.isEmpty {
                hiddenHubs = true
                nodes = nodes.filter { !drop.contains($0.key) }
                filteredEdges = filteredEdges.filter {
                    !drop.contains($0.from) && !drop.contains($0.to)
                }
            }
        }

        var isolatedFocus = false
        if let focus = options.focusObjectID {
            isolatedFocus = true
            if nodes[focus] == nil {
                nodes = [:]
                filteredEdges = []
            } else {
                var keep: Set<ObjectID> = [focus]
                for edge in filteredEdges {
                    if edge.from == focus { keep.insert(edge.to) }
                    if edge.to == focus { keep.insert(edge.from) }
                }
                nodes = nodes.filter { keep.contains($0.key) }
                filteredEdges = filteredEdges.filter {
                    keep.contains($0.from) && keep.contains($0.to)
                }
            }
        }

        let resolvedCount = filteredEdges.count
        var truncated = false

        // Degree map for cap preference (after hide / focus).
        var degree = degreeMap(edges: filteredEdges)

        if nodes.count > options.maxNodes {
            truncated = true
            let ranked = nodes.values.sorted { a, b in
                let da = degree[a.id, default: 0]
                let db = degree[b.id, default: 0]
                if da != db { return da > db }
                return a.id.uuidString.lowercased() < b.id.uuidString.lowercased()
            }
            let keep = Set(ranked.prefix(options.maxNodes).map(\.id))
            nodes = nodes.filter { keep.contains($0.key) }
            filteredEdges = filteredEdges.filter {
                keep.contains($0.from) && keep.contains($0.to)
            }
        }

        if filteredEdges.count > options.maxEdges {
            truncated = true
            // Prefer edges involving higher-degree nodes; stable tie-break.
            filteredEdges = filteredEdges.sorted { a, b in
                let da = degree[a.from, default: 0] + degree[a.to, default: 0]
                let db = degree[b.from, default: 0] + degree[b.to, default: 0]
                if da != db { return da > db }
                return a.id < b.id
            }
            filteredEdges = Array(filteredEdges.prefix(options.maxEdges))
            let used = Set(filteredEdges.flatMap { [$0.from, $0.to] })
            nodes = nodes.filter { used.contains($0.key) }
        }

        let orderedNodes = nodes.values.sorted {
            let t0 = $0.title.lowercased()
            let t1 = $1.title.lowercased()
            if t0 != t1 { return t0 < t1 }
            return $0.id.uuidString.lowercased() < $1.id.uuidString.lowercased()
        }

        return GraphSnapshot(
            nodes: orderedNodes,
            edges: filteredEdges,
            truncated: truncated,
            resolvedEdgeCount: resolvedCount,
            unresolvedLinkCount: unresolvedLinkCount,
            hiddenHubs: hiddenHubs,
            isolatedFocus: isolatedFocus
        )
    }

    private static func degreeMap(edges: [GraphEdge]) -> [ObjectID: Int] {
        var degree: [ObjectID: Int] = [:]
        for edge in edges {
            degree[edge.from, default: 0] += 1
            degree[edge.to, default: 0] += 1
        }
        return degree
    }
}

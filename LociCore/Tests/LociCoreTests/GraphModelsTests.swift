import XCTest
@testable import LociCore

final class GraphModelsTests: XCTestCase {
    func testAssemblyBuildsEdgesAndNodes() {
        let a = ObjectID(UUID(uuidString: "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1")!)
        let b = ObjectID(UUID(uuidString: "bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb2")!)
        let nodes: [ObjectID: GraphNode] = [
            a: GraphNode(id: a, title: "A", typeID: .page),
            b: GraphNode(id: b, title: "B", typeID: .page),
        ]
        let edges = [GraphEdge(from: a, to: b, label: "Page B")]
        let snap = GraphAssembly.assemble(
            nodesByID: nodes,
            edges: edges,
            unresolvedLinkCount: 1,
            options: .default
        )
        XCTAssertEqual(snap.nodes.count, 2)
        XCTAssertEqual(snap.edges.count, 1)
        XCTAssertEqual(snap.unresolvedLinkCount, 1)
        XCTAssertFalse(snap.truncated)
        XCTAssertEqual(snap.resolvedEdgeCount, 1)
    }

    func testTypeFilterDropsOtherTypes() {
        let a = ObjectID(UUID(uuidString: "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1")!)
        let b = ObjectID(UUID(uuidString: "bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb2")!)
        let c = ObjectID(UUID(uuidString: "cccccccc-cccc-4ccc-8ccc-ccccccccccc3")!)
        let book = ObjectTypeID("book")
        let nodes: [ObjectID: GraphNode] = [
            a: GraphNode(id: a, title: "A", typeID: .page),
            b: GraphNode(id: b, title: "B", typeID: book),
            c: GraphNode(id: c, title: "C", typeID: book),
        ]
        let edges = [
            GraphEdge(from: a, to: b),
            GraphEdge(from: b, to: c),
        ]
        let snap = GraphAssembly.assemble(
            nodesByID: nodes,
            edges: edges,
            unresolvedLinkCount: 0,
            options: GraphBuildOptions(typeFilter: book)
        )
        XCTAssertEqual(Set(snap.nodes.map(\.id)), [b, c])
        XCTAssertEqual(snap.edges.count, 1)
        XCTAssertEqual(snap.edges.first?.from, b)
        XCTAssertEqual(snap.edges.first?.to, c)
    }

    func testNodeCapKeepsHighestDegree() {
        let hub = ObjectID(UUID(uuidString: "11111111-1111-4111-8111-111111111111")!)
        let a = ObjectID(UUID(uuidString: "22222222-2222-4222-8222-222222222221")!)
        let b = ObjectID(UUID(uuidString: "22222222-2222-4222-8222-222222222222")!)
        let c = ObjectID(UUID(uuidString: "22222222-2222-4222-8222-222222222223")!)
        let d = ObjectID(UUID(uuidString: "22222222-2222-4222-8222-222222222224")!)
        let e = ObjectID(UUID(uuidString: "33333333-3333-4333-8333-333333333331")!)
        let f = ObjectID(UUID(uuidString: "33333333-3333-4333-8333-333333333332")!)

        var nodes: [ObjectID: GraphNode] = [:]
        for (id, title) in [
            (hub, "Hub"), (a, "A"), (b, "B"), (c, "C"), (d, "D"), (e, "E"), (f, "F"),
        ] {
            nodes[id] = GraphNode(id: id, title: title, typeID: .page)
        }
        let edges = [
            GraphEdge(from: hub, to: a),
            GraphEdge(from: hub, to: b),
            GraphEdge(from: hub, to: c),
            GraphEdge(from: hub, to: d),
            GraphEdge(from: e, to: f),
        ]
        let snap = GraphAssembly.assemble(
            nodesByID: nodes,
            edges: edges,
            unresolvedLinkCount: 0,
            options: GraphBuildOptions(maxNodes: 3, maxEdges: 400)
        )
        XCTAssertTrue(snap.truncated)
        XCTAssertLessThanOrEqual(snap.nodes.count, 3)
        XCTAssertTrue(snap.nodes.contains(where: { $0.id == hub }))
    }

    func testEdgeCapTruncates() {
        let ids = (1...6).map { i -> ObjectID in
            let hex = String(format: "%012x", i)
            return ObjectID(UUID(uuidString: "aaaaaaaa-aaaa-4aaa-8aaa-\(hex)")!)
        }
        var nodes: [ObjectID: GraphNode] = [:]
        for (i, id) in ids.enumerated() {
            nodes[id] = GraphNode(id: id, title: "N\(i)", typeID: .page)
        }
        var edges: [GraphEdge] = []
        for i in 0..<(ids.count - 1) {
            edges.append(GraphEdge(from: ids[i], to: ids[i + 1]))
        }
        let snap = GraphAssembly.assemble(
            nodesByID: nodes,
            edges: edges,
            unresolvedLinkCount: 0,
            options: GraphBuildOptions(maxNodes: 150, maxEdges: 2)
        )
        XCTAssertTrue(snap.truncated)
        XCTAssertEqual(snap.edges.count, 2)
        XCTAssertEqual(snap.resolvedEdgeCount, 5)
    }

    func testHideDegreeDropsHubsBeforeCaps() {
        let hub = ObjectID(UUID(uuidString: "11111111-1111-4111-8111-111111111111")!)
        let a = ObjectID(UUID(uuidString: "22222222-2222-4222-8222-222222222221")!)
        let b = ObjectID(UUID(uuidString: "22222222-2222-4222-8222-222222222222")!)
        let c = ObjectID(UUID(uuidString: "22222222-2222-4222-8222-222222222223")!)
        let d = ObjectID(UUID(uuidString: "22222222-2222-4222-8222-222222222224")!)
        let e = ObjectID(UUID(uuidString: "33333333-3333-4333-8333-333333333331")!)
        let f = ObjectID(UUID(uuidString: "33333333-3333-4333-8333-333333333332")!)

        var nodes: [ObjectID: GraphNode] = [:]
        for (id, title) in [
            (hub, "Hub"), (a, "A"), (b, "B"), (c, "C"), (d, "D"), (e, "E"), (f, "F"),
        ] {
            nodes[id] = GraphNode(id: id, title: title, typeID: .page)
        }
        let edges = [
            GraphEdge(from: hub, to: a),
            GraphEdge(from: hub, to: b),
            GraphEdge(from: hub, to: c),
            GraphEdge(from: hub, to: d),
            GraphEdge(from: e, to: f),
        ]

        let hidden = GraphAssembly.assemble(
            nodesByID: nodes,
            edges: edges,
            unresolvedLinkCount: 0,
            options: GraphBuildOptions(hideDegreeAtOrAbove: 4)
        )
        XCTAssertTrue(hidden.hiddenHubs)
        XCTAssertFalse(hidden.truncated)
        XCTAssertFalse(hidden.nodes.contains(where: { $0.id == hub }))
        XCTAssertEqual(Set(hidden.nodes.map(\.id)), [a, b, c, d, e, f])
        XCTAssertEqual(hidden.edges.count, 1)
        XCTAssertEqual(hidden.edges.first?.from, e)
        XCTAssertEqual(hidden.edges.first?.to, f)

        // Caps keep hubs; hide-before-caps must drop the hub even when maxNodes would keep it.
        let hiddenThenCapped = GraphAssembly.assemble(
            nodesByID: nodes,
            edges: edges,
            unresolvedLinkCount: 0,
            options: GraphBuildOptions(maxNodes: 3, hideDegreeAtOrAbove: 4)
        )
        XCTAssertTrue(hiddenThenCapped.hiddenHubs)
        XCTAssertFalse(hiddenThenCapped.nodes.contains(where: { $0.id == hub }))
        XCTAssertLessThanOrEqual(hiddenThenCapped.nodes.count, 3)
    }

    func testFocusKeepsNodeAndOneHopNeighbors() {
        let hub = ObjectID(UUID(uuidString: "11111111-1111-4111-8111-111111111111")!)
        let a = ObjectID(UUID(uuidString: "22222222-2222-4222-8222-222222222221")!)
        let b = ObjectID(UUID(uuidString: "22222222-2222-4222-8222-222222222222")!)
        let e = ObjectID(UUID(uuidString: "33333333-3333-4333-8333-333333333331")!)
        let f = ObjectID(UUID(uuidString: "33333333-3333-4333-8333-333333333332")!)

        var nodes: [ObjectID: GraphNode] = [:]
        for (id, title) in [(hub, "Hub"), (a, "A"), (b, "B"), (e, "E"), (f, "F")] {
            nodes[id] = GraphNode(id: id, title: title, typeID: .page)
        }
        let edges = [
            GraphEdge(from: hub, to: a),
            GraphEdge(from: hub, to: b),
            GraphEdge(from: e, to: f),
        ]

        let focused = GraphAssembly.assemble(
            nodesByID: nodes,
            edges: edges,
            unresolvedLinkCount: 0,
            options: GraphBuildOptions(focusObjectID: a)
        )
        XCTAssertTrue(focused.isolatedFocus)
        XCTAssertEqual(Set(focused.nodes.map(\.id)), [hub, a])
        XCTAssertEqual(focused.edges.count, 1)
        XCTAssertEqual(focused.degree(of: a), 1)
        XCTAssertEqual(focused.neighborCount(of: a), 1)
        XCTAssertFalse(focused.nodes.contains(where: { $0.id == e }))
    }

    func testFocusProtectsHubFromHide() {
        let hub = ObjectID(UUID(uuidString: "11111111-1111-4111-8111-111111111111")!)
        let a = ObjectID(UUID(uuidString: "22222222-2222-4222-8222-222222222221")!)
        let b = ObjectID(UUID(uuidString: "22222222-2222-4222-8222-222222222222")!)
        let e = ObjectID(UUID(uuidString: "33333333-3333-4333-8333-333333333331")!)
        let f = ObjectID(UUID(uuidString: "33333333-3333-4333-8333-333333333332")!)

        var nodes: [ObjectID: GraphNode] = [:]
        for (id, title) in [(hub, "Hub"), (a, "A"), (b, "B"), (e, "E"), (f, "F")] {
            nodes[id] = GraphNode(id: id, title: title, typeID: .page)
        }
        let edges = [
            GraphEdge(from: hub, to: a),
            GraphEdge(from: hub, to: b),
            GraphEdge(from: e, to: f),
        ]

        let snap = GraphAssembly.assemble(
            nodesByID: nodes,
            edges: edges,
            unresolvedLinkCount: 0,
            options: GraphBuildOptions(
                hideDegreeAtOrAbove: 2,
                focusObjectID: hub
            )
        )
        XCTAssertTrue(snap.isolatedFocus)
        XCTAssertTrue(snap.nodes.contains(where: { $0.id == hub }))
        XCTAssertEqual(Set(snap.nodes.map(\.id)), [hub, a, b])
        XCTAssertFalse(snap.nodes.contains(where: { $0.id == e }))
        XCTAssertEqual(GraphBuildOptions.defaultHideHubDegree, 8)
    }

    func testLayoutIsDeterministic() {
        let a = ObjectID(UUID(uuidString: "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1")!)
        let b = ObjectID(UUID(uuidString: "bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb2")!)
        let snap = GraphSnapshot(
            nodes: [
                GraphNode(id: a, title: "A", typeID: .page),
                GraphNode(id: b, title: "B", typeID: .page),
            ],
            edges: [GraphEdge(from: a, to: b)]
        )
        let config = GraphLayoutEngine.Config(width: 400, height: 300, iterations: 40)
        let l1 = GraphLayoutEngine.layout(snap, config: config)
        let l2 = GraphLayoutEngine.layout(snap, config: config)
        XCTAssertEqual(l1, l2)
        XCTAssertNotNil(l1.point(for: a))
        XCTAssertNotNil(l1.point(for: b))
        let p = l1.point(for: a)!
        XCTAssertGreaterThanOrEqual(p.x, 0)
        XCTAssertLessThanOrEqual(p.x, 400)
        XCTAssertGreaterThanOrEqual(p.y, 0)
        XCTAssertLessThanOrEqual(p.y, 300)
    }

    func testStableHashConstant() {
        XCTAssertEqual(GraphLayoutEngine.stableHash("abc"), GraphLayoutEngine.stableHash("abc"))
        XCTAssertNotEqual(GraphLayoutEngine.stableHash("abc"), GraphLayoutEngine.stableHash("abd"))
    }
}

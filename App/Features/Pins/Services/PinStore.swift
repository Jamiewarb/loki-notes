import Foundation
import LociCore

/// Thin feature-local facade over `PinServing` + display resolution (PR34).
///
/// Features must not import other features; composition injects protocols.
public struct PinStore: Sendable {
    private let pins: any PinServing
    private let resolver: PinResolver

    public init(
        pins: any PinServing,
        index: (any IndexQuerying)?,
        objects: (any ObjectServing)?
    ) {
        self.pins = pins
        self.resolver = PinResolver(pins: pins, index: index, objects: objects)
    }

    public func rows() async throws -> [PinnedObjectRow] {
        try await resolver.resolvedRows()
    }

    @discardableResult
    public func pin(_ id: ObjectID) async throws -> [ObjectID] {
        try await pins.pinObject(id)
    }

    @discardableResult
    public func unpin(_ id: ObjectID) async throws -> [ObjectID] {
        try await pins.unpinObject(id)
    }

    public func isPinned(_ id: ObjectID) async throws -> Bool {
        try await pins.isPinned(id)
    }
}

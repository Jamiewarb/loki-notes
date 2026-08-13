import Foundation

/// Typed navigation used by AppShell and features. No cross-feature view imports.
public protocol Navigating: Sendable {
    func open(route: Route) async
    func open(objectID: ObjectID) async
}

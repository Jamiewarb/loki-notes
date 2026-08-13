import Foundation

/// Shared error surface for Loci packages. Features should map these to UI, not invent I/O errors.
public enum LociError: Error, Sendable, Equatable {
    case notImplemented(String)
    case invalidObjectID(String)
    case vaultUnavailable
    case indexUnavailable
    case objectNotFound(ObjectID)
    case schemaNotFound(String)
    case invalidRelativePath(String)
    case fileNotFound(String)
    case pathOutsideVault(String)
    case coordinationFailed(String)
}

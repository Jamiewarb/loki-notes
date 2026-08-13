import Foundation

/// Shared error surface for Loci packages. Features should map these to UI, not invent I/O errors.
public enum LociError: Error, Sendable, Equatable {
    case notImplemented(String)
    case invalidObjectID(String)
    case vaultUnavailable
    case indexUnavailable
    case objectNotFound(ObjectID)
    case schemaNotFound(String)
    /// Type slug already has a `.loci/types/<slug>.json` file.
    case typeAlreadyExists(String)
    /// Built-in types (Page / Daily) cannot be deleted casually.
    case typeProtected(String)
    /// Slug empty, reserved, or not `[a-z0-9-]+`.
    case invalidTypeSlug(String)
    /// Custom type still has object markdown under `objects/<slug>/`.
    case typeNotEmpty(String)
    /// Property id empty or duplicate on a type.
    case invalidPropertyID(String)
    /// Property def not found on the type.
    case propertyNotFound(String)
    /// Template id empty, malformed, or reserved shape.
    case invalidTemplateID(String)
    /// Template file / id not found under `.loci/templates/`.
    case templateNotFound(String)
    /// Template id already exists.
    case templateAlreadyExists(String)
    case invalidRelativePath(String)
    case fileNotFound(String)
    case pathOutsideVault(String)
    case coordinationFailed(String)
}

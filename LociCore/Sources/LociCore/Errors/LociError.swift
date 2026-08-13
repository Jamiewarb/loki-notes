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
    /// Collection id empty, malformed, or reserved shape.
    case invalidCollectionID(String)
    /// Collection file / id not found under `.loci/collections/`.
    case collectionNotFound(String)
    /// Collection id already exists.
    case collectionAlreadyExists(String)
    /// Object is not a member of the collection (remove no-op failure).
    case collectionMemberNotFound(String)
    /// Query id empty or malformed.
    case invalidQueryID(String)
    /// Query file / id not found under `.loci/queries/`.
    case queryNotFound(String)
    /// Query id already exists.
    case queryAlreadyExists(String)
    case invalidRelativePath(String)
    case fileNotFound(String)
    case pathOutsideVault(String)
    case coordinationFailed(String)
    /// Ubiquity download / ensure-local failed (Apple).
    case downloadFailed(String)
    /// Import source root missing or not a directory.
    case importSourceNotFound(String)
    /// Import produced no markdown candidates.
    case importEmpty(String)
    /// Type conversion refused (daily notes, same type, missing schema, …).
    case typeConversionNotAllowed(String)
    /// Remote AI upload refused — user has not opted in (PR30).
    case aiUploadNotAllowed
    /// Preferred AI provider unavailable on this platform / configuration.
    case aiProviderUnavailable(String)
    /// BYOK API key missing from credential store (Application Support / Keychain).
    case aiCredentialsMissing
}

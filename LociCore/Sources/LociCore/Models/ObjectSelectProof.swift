import Foundation

/// Linux-testable notes for the object-select picker (PR40).
///
/// Values persist as ObjectID strings in YAML (`PropertyValue.objectSelect`).
/// Indexing merges those ids into the disposable `links` table. The picker
/// queries `IndexQuerying.linkCandidates` — Properties must not import Links.
/// Derived UI must not rewrite note bodies with `[[wiki-links]]`.
public struct ObjectSelectProof: Hashable, Sendable, Equatable, Codable {
    /// Picker rows come from `IndexQuerying.linkCandidates` (code present + demo hit).
    public var pickerUsesIndexCandidates: Bool
    /// YAML stores ObjectID / `frontMatterIDString` values, not absolute disk paths.
    public var storesObjectIDs: Bool
    /// Object-select ids are merged into the index `links` table (backlinks + outgoing).
    public var createsRealLinks: Bool
    /// Saving an object-select value does not insert `[[…]]` into the markdown body.
    public var doesNotRewriteBody: Bool
    public var indexInsideVault: Bool

    public init(
        pickerUsesIndexCandidates: Bool,
        storesObjectIDs: Bool,
        createsRealLinks: Bool,
        doesNotRewriteBody: Bool,
        indexInsideVault: Bool
    ) {
        self.pickerUsesIndexCandidates = pickerUsesIndexCandidates
        self.storesObjectIDs = storesObjectIDs
        self.createsRealLinks = createsRealLinks
        self.doesNotRewriteBody = doesNotRewriteBody
        self.indexInsideVault = indexInsideVault
    }

    /// Evaluate proof from a save + index round-trip (no GRDB in LociCore).
    public static func evaluate(
        storedIDs: [String],
        yamlSnippet: String,
        bodyMarkdown: String,
        candidateCount: Int,
        excludedObjectAppearsInCandidates: Bool,
        backlinkCount: Int,
        outgoingCount: Int,
        indexInsideVault: Bool
    ) -> ObjectSelectProof {
        let ids = storedIDs.map {
            ObjectSelectID.persistableString(from: $0)
        }
        let yaml = yamlSnippet.lowercased()
        let stores =
            !ids.isEmpty
            && ids.allSatisfy { ObjectSelectID.isObjectIDString($0) }
            && ids.allSatisfy { yaml.contains($0.lowercased()) }
            && !ObjectSelectID.yamlLooksLikeAbsolutePath(yamlSnippet)
        return ObjectSelectProof(
            pickerUsesIndexCandidates: candidateCount > 0 && !excludedObjectAppearsInCandidates,
            storesObjectIDs: stores,
            createsRealLinks: backlinkCount > 0 && outgoingCount > 0,
            doesNotRewriteBody: !bodyMarkdown.contains("[["),
            indexInsideVault: indexInsideVault
        )
    }
}

/// Persist object-select values as ObjectID strings (lowercase UUID or daily key).
public enum ObjectSelectID: Sendable {
    /// Canonical string written to YAML / drafts. UUID → lowercase; daily → `daily-YYYY-MM-DD`.
    public static func persistableString(from raw: String) -> String {
        let trimmed = stripWikiBrackets(raw.trimmingCharacters(in: .whitespacesAndNewlines))
        if let id = ObjectID(parsing: trimmed) {
            return id.frontMatterIDString
        }
        return trimmed
    }

    public static func isObjectIDString(_ raw: String) -> Bool {
        ObjectID(parsing: stripWikiBrackets(raw)) != nil
    }

    public static func looksLikeAbsolutePath(_ raw: String) -> Bool {
        let t = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if t.hasPrefix("file:") { return true }
        if t.hasPrefix("/") { return true }
        if t.count >= 3 {
            let second = t[t.index(t.startIndex, offsetBy: 1)]
            if second == ":", t[t.startIndex].isLetter { return true }
        }
        return false
    }

    public static func yamlLooksLikeAbsolutePath(_ yaml: String) -> Bool {
        let needles = ["file://", "/tmp/", "/Users/", "/home/", "/var/", "/opt/", "/private/"]
        return needles.contains { yaml.contains($0) }
    }

    public static func parseList(_ draft: String) -> [String] {
        draft.split(separator: ",")
            .map { persistableString(from: String($0)) }
            .filter { !$0.isEmpty }
    }

    public static func draftString(from ids: [String]) -> String {
        ids.map { persistableString(from: $0) }.joined(separator: ", ")
    }

    public static func stripWikiBrackets(_ raw: String) -> String {
        let t = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if t.hasPrefix("[["), t.hasSuffix("]]"), t.count >= 4 {
            return String(t.dropFirst(2).dropLast(2)).trimmingCharacters(in: .whitespaces)
        }
        return t
    }
}

/// Contract notes so XCTest / DevHarness never import SwiftUI or Features/Links.
public enum ObjectSelectNotes: Sendable {
    public static let pickerUsesIndexCandidates = true
    public static let queryProtocol = "IndexQuerying.linkCandidates"
    public static let persistObjectIDsNotPaths = true
    public static let doesNotRewriteBody = true
    public static let createsRealLinks = true
    /// Properties duplicates a small picker; it must not import `App/Features/Links`.
    public static let propertiesMustNotImportLinks = true
}

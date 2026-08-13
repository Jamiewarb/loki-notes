import Foundation

/// LociMarkdown public surface (parse / serialize Loci MD ↔ BlockAST + frontmatter).
///
/// YAML choice: hand-rolled `SimpleYAML` subset — no SPM YAML dependency (Linux-friendly).
public enum LociMarkdownModule {
    public static let version = "0.2.0-pr26"

    public static func parse(_ markdown: String) throws -> LociDocument {
        try MarkdownParser().parse(markdown)
    }

    public static func serialize(_ document: LociDocument) -> String {
        MarkdownSerializer().serialize(document)
    }

    /// Parse then serialize — useful for normalization / harness demos.
    public static func roundTrip(_ markdown: String) throws -> String {
        serialize(try parse(markdown))
    }
}

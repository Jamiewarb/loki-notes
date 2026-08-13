// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Loci",
    platforms: [
        .macOS(.v14),
        .iOS(.v17),
    ],
    products: [
        .library(name: "LociCore", targets: ["LociCore"]),
        .library(name: "LociVault", targets: ["LociVault"]),
        .library(name: "LociMarkdown", targets: ["LociMarkdown"]),
        .library(name: "LociIndex", targets: ["LociIndex"]),
        .library(name: "LociDesignSystem", targets: ["LociDesignSystem"]),
        .executable(name: "loci-vault-demo", targets: ["loci-vault-demo"]),
        .executable(name: "loci-markdown-demo", targets: ["loci-markdown-demo"]),
        .executable(name: "loci-index-demo", targets: ["loci-index-demo"]),
    ],
    dependencies: [
        // GRDB builds on Swift 6.2 Linux (confirmed PR07) and Apple platforms.
        .package(url: "https://github.com/groue/GRDB.swift.git", from: "7.0.0"),
    ],
    targets: [
        // Core: models, IDs, errors, protocols — no SwiftUI, no I/O
        .target(
            name: "LociCore",
            path: "LociCore/Sources/LociCore"
        ),
        .testTarget(
            name: "LociCoreTests",
            dependencies: ["LociCore"],
            path: "LociCore/Tests/LociCoreTests"
        ),

        // Vault: ubiquity/local roots, coordinated I/O, trash/tombstones (PR04)
        .target(
            name: "LociVault",
            dependencies: ["LociCore"],
            path: "LociVault/Sources/LociVault"
        ),
        .executableTarget(
            name: "loci-vault-demo",
            dependencies: ["LociVault", "LociCore"],
            path: "LociVault/Sources/LociVaultDemo"
        ),
        .testTarget(
            name: "LociVaultTests",
            dependencies: ["LociVault"],
            path: "LociVault/Tests/LociVaultTests"
        ),

        // Markdown: Loci MD ↔ BlockAST + YAML frontmatter (PR06)
        .target(
            name: "LociMarkdown",
            dependencies: ["LociCore"],
            path: "LociMarkdown/Sources/LociMarkdown"
        ),
        .testTarget(
            name: "LociMarkdownTests",
            dependencies: ["LociMarkdown", "LociCore"],
            path: "LociMarkdown/Tests/LociMarkdownTests",
            resources: [.copy("Fixtures")]
        ),
        .executableTarget(
            name: "loci-markdown-demo",
            dependencies: ["LociMarkdown"],
            path: "LociMarkdown/Sources/LociMarkdownDemo"
        ),

        // Index: SQLite projection in Application Support (never inside the vault)
        .target(
            name: "LociIndex",
            dependencies: [
                "LociCore",
                "LociMarkdown",
                .product(name: "GRDB", package: "GRDB.swift"),
            ],
            path: "LociIndex/Sources/LociIndex"
        ),
        .testTarget(
            name: "LociIndexTests",
            dependencies: ["LociIndex", "LociVault", "LociMarkdown", "LociCore"],
            path: "LociIndex/Tests/LociIndexTests"
        ),
        .executableTarget(
            name: "loci-index-demo",
            dependencies: ["LociIndex", "LociVault", "LociMarkdown", "LociCore"],
            path: "LociIndex/Sources/LociIndexDemo"
        ),

        // Design system: tokens (Linux-testable) + SwiftUI primitives (Apple)
        .target(
            name: "LociDesignSystem",
            path: "LociDesignSystem/Sources/LociDesignSystem"
        ),
        .testTarget(
            name: "LociDesignSystemTests",
            dependencies: ["LociDesignSystem"],
            path: "LociDesignSystem/Tests/LociDesignSystemTests"
        ),
    ]
)

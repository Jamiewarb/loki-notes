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
        .executable(name: "loci-editor-demo", targets: ["loci-editor-demo"]),
        .executable(name: "loci-index-demo", targets: ["loci-index-demo"]),
        .executable(name: "loci-objects-demo", targets: ["loci-objects-demo"]),
        .executable(name: "loci-daily-demo", targets: ["loci-daily-demo"]),
        .executable(name: "loci-created-today-demo", targets: ["loci-created-today-demo"]),
        .executable(name: "loci-types-demo", targets: ["loci-types-demo"]),
        .executable(name: "loci-properties-demo", targets: ["loci-properties-demo"]),
        .executable(name: "loci-templates-demo", targets: ["loci-templates-demo"]),
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

        // Vault: ubiquity/local roots, coordinated I/O, trash/tombstones (PR04) + ObjectService (PR08)
        .target(
            name: "LociVault",
            dependencies: ["LociCore", "LociMarkdown"],
            path: "LociVault/Sources/LociVault"
        ),
        .executableTarget(
            name: "loci-vault-demo",
            dependencies: ["LociVault", "LociCore"],
            path: "LociVault/Sources/LociVaultDemo"
        ),
        .executableTarget(
            name: "loci-objects-demo",
            dependencies: ["LociVault", "LociIndex", "LociMarkdown", "LociCore"],
            path: "LociVault/Sources/LociObjectsDemo"
        ),
        .executableTarget(
            name: "loci-daily-demo",
            dependencies: ["LociVault", "LociIndex", "LociMarkdown", "LociCore"],
            path: "LociVault/Sources/LociDailyDemo"
        ),
        .executableTarget(
            name: "loci-created-today-demo",
            dependencies: ["LociVault", "LociIndex", "LociMarkdown", "LociCore"],
            path: "LociVault/Sources/LociCreatedTodayDemo"
        ),
        .executableTarget(
            name: "loci-types-demo",
            dependencies: ["LociVault", "LociIndex", "LociMarkdown", "LociCore"],
            path: "LociVault/Sources/LociTypesDemo"
        ),
        .executableTarget(
            name: "loci-properties-demo",
            dependencies: ["LociVault", "LociIndex", "LociMarkdown", "LociCore"],
            path: "LociVault/Sources/LociPropertiesDemo"
        ),
        .executableTarget(
            name: "loci-templates-demo",
            dependencies: ["LociVault", "LociIndex", "LociMarkdown", "LociCore"],
            path: "LociVault/Sources/LociTemplatesDemo"
        ),
        .testTarget(
            name: "LociVaultTests",
            dependencies: ["LociVault", "LociIndex", "LociMarkdown", "LociCore"],
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
        .executableTarget(
            name: "loci-editor-demo",
            dependencies: ["LociMarkdown", "LociCore"],
            path: "LociMarkdown/Sources/LociEditorDemo"
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

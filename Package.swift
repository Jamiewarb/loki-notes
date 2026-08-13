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
        .executable(name: "loci-para-demo", targets: ["loci-para-demo"]),
        .executable(name: "loci-links-demo", targets: ["loci-links-demo"]),
        .executable(name: "loci-tags-demo", targets: ["loci-tags-demo"]),
        .executable(name: "loci-search-demo", targets: ["loci-search-demo"]),
        .executable(name: "loci-tasks-demo", targets: ["loci-tasks-demo"]),
        .executable(name: "loci-media-demo", targets: ["loci-media-demo"]),
        .executable(name: "loci-sync-demo", targets: ["loci-sync-demo"]),
        .executable(name: "loci-collections-demo", targets: ["loci-collections-demo"]),
        .executable(name: "loci-queries-demo", targets: ["loci-queries-demo"]),
        .executable(name: "loci-graph-demo", targets: ["loci-graph-demo"]),
        .executable(name: "loci-calendar-demo", targets: ["loci-calendar-demo"]),
        .executable(name: "loci-capture-demo", targets: ["loci-capture-demo"]),
        .executable(name: "loci-import-demo", targets: ["loci-import-demo"]),
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
        .executableTarget(
            name: "loci-para-demo",
            dependencies: ["LociVault", "LociIndex", "LociMarkdown", "LociCore"],
            path: "LociVault/Sources/LociPARADemo"
        ),
        .executableTarget(
            name: "loci-links-demo",
            dependencies: ["LociVault", "LociIndex", "LociMarkdown", "LociCore"],
            path: "LociVault/Sources/LociLinksDemo"
        ),
        .executableTarget(
            name: "loci-tags-demo",
            dependencies: ["LociVault", "LociIndex", "LociMarkdown", "LociCore"],
            path: "LociVault/Sources/LociTagsDemo"
        ),
        .executableTarget(
            name: "loci-search-demo",
            dependencies: ["LociIndex", "LociVault", "LociMarkdown", "LociCore"],
            path: "LociIndex/Sources/LociSearchDemo"
        ),
        .executableTarget(
            name: "loci-tasks-demo",
            dependencies: ["LociIndex", "LociVault", "LociMarkdown", "LociCore"],
            path: "LociIndex/Sources/LociTasksDemo"
        ),
        .executableTarget(
            name: "loci-media-demo",
            dependencies: ["LociVault", "LociIndex", "LociMarkdown", "LociCore"],
            path: "LociVault/Sources/LociMediaDemo"
        ),
        .executableTarget(
            name: "loci-sync-demo",
            dependencies: ["LociVault", "LociIndex", "LociMarkdown", "LociCore"],
            path: "LociVault/Sources/LociSyncDemo"
        ),
        .executableTarget(
            name: "loci-collections-demo",
            dependencies: ["LociVault", "LociIndex", "LociMarkdown", "LociCore"],
            path: "LociVault/Sources/LociCollectionsDemo"
        ),
        .executableTarget(
            name: "loci-queries-demo",
            dependencies: ["LociVault", "LociIndex", "LociMarkdown", "LociCore"],
            path: "LociVault/Sources/LociQueriesDemo"
        ),
        .executableTarget(
            name: "loci-graph-demo",
            dependencies: ["LociVault", "LociIndex", "LociMarkdown", "LociCore"],
            path: "LociVault/Sources/LociGraphDemo"
        ),
        .executableTarget(
            name: "loci-calendar-demo",
            dependencies: ["LociVault", "LociIndex", "LociMarkdown", "LociCore"],
            path: "LociVault/Sources/LociCalendarDemo"
        ),
        .executableTarget(
            name: "loci-capture-demo",
            dependencies: ["LociVault", "LociIndex", "LociMarkdown", "LociCore"],
            path: "LociVault/Sources/LociCaptureDemo"
        ),
        .executableTarget(
            name: "loci-import-demo",
            dependencies: ["LociVault", "LociIndex", "LociMarkdown", "LociCore"],
            path: "LociVault/Sources/LociImportDemo"
        ),
        .testTarget(
            name: "LociVaultTests",
            dependencies: ["LociVault", "LociIndex", "LociMarkdown", "LociCore"],
            path: "LociVault/Tests/LociVaultTests",
            resources: [.copy("Fixtures")]
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

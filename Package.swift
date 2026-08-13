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

        // Markdown: stub — parse/serialize lands in PR06
        .target(
            name: "LociMarkdown",
            dependencies: ["LociCore"],
            path: "LociMarkdown/Sources/LociMarkdown"
        ),
        .testTarget(
            name: "LociMarkdownTests",
            dependencies: ["LociMarkdown"],
            path: "LociMarkdown/Tests/LociMarkdownTests"
        ),

        // Index: stub — SQLite projection lands in PR07 (Application Support only)
        .target(
            name: "LociIndex",
            dependencies: ["LociCore"],
            path: "LociIndex/Sources/LociIndex"
        ),
        .testTarget(
            name: "LociIndexTests",
            dependencies: ["LociIndex"],
            path: "LociIndex/Tests/LociIndexTests"
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

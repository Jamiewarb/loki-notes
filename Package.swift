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

        // Vault: stub — iCloud/local roots land in PR04
        .target(
            name: "LociVault",
            dependencies: ["LociCore"],
            path: "LociVault/Sources/LociVault"
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

        // Design system: stub — tokens/components land in PR02
        .target(
            name: "LociDesignSystem",
            path: "LociDesignSystem/Sources/LociDesignSystem"
        ),
    ]
)

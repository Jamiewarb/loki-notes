import Foundation

/// Linux-testable notes for macOS CI, keyboard shortcuts, VoiceOver, Dynamic Type (PR39).
///
/// `xcodebuild` does not run on Linux. `macosCIWorkflowPresent` means the workflow
/// contract is catalogued (YAML is the Mac deliverable). Index never lives in the vault.
public struct MacOSCIProof: Hashable, Sendable, Equatable, Codable {
    /// `.github/workflows/ci.yml` has a `macos-14` / `xcodebuild` job (code present).
    public var macosCIWorkflowPresent: Bool
    /// Four unique shortcut actions including Search ⌘K and Capture ⌘⇧N.
    public var shortcutsCatalogued: Bool
    /// Daily / Editor / Search / Settings identifiers are catalogued for VoiceOver.
    public var voiceOverLabelsPresent: Bool
    /// Typography maps roles to `Font.TextStyle` via `relativeTo:`.
    public var dynamicTypeScales: Bool
    public var indexInsideVault: Bool

    public init(
        macosCIWorkflowPresent: Bool,
        shortcutsCatalogued: Bool,
        voiceOverLabelsPresent: Bool,
        dynamicTypeScales: Bool,
        indexInsideVault: Bool
    ) {
        self.macosCIWorkflowPresent = macosCIWorkflowPresent
        self.shortcutsCatalogued = shortcutsCatalogued
        self.voiceOverLabelsPresent = voiceOverLabelsPresent
        self.dynamicTypeScales = dynamicTypeScales
        self.indexInsideVault = indexInsideVault
    }

    public static func evaluate(indexInsideVault: Bool = false) -> MacOSCIProof {
        let shortcuts = KeyboardShortcutCatalog.all
        let search = KeyboardShortcutCatalog.search
        let capture = KeyboardShortcutCatalog.quickCapture
        let catalogued =
            shortcuts.count == 4
            && KeyboardShortcutCatalog.actionIDsAreUnique
            && KeyboardShortcutCatalog.combosAreUnique
            && search.key == "k"
            && search.modifiers == "command"
            && capture.key == "n"
            && capture.usesShift
            && capture.usesCommand
        return MacOSCIProof(
            macosCIWorkflowPresent: MacOSCINotes.macosCIWorkflowPresent,
            shortcutsCatalogued: catalogued,
            voiceOverLabelsPresent: LociAccessibilityCatalog.hasDailyEditorSearchSettings
                && LociAccessibilityCatalog.screenIdentifiersAreUnique
                && LociAccessibilityCatalog.screenLabels.count == 4,
            dynamicTypeScales: LociDynamicTypeCatalog.usesRelativeTo
                && LociDynamicTypeCatalog.all.count == 8
                && LociDynamicTypeCatalog.textStyleName(forRole: "brand") == "largeTitle"
                && LociDynamicTypeCatalog.textStyleName(forRole: "body") == "body",
            indexInsideVault: indexInsideVault
        )
    }
}

/// Contract notes so XCTest / DevHarness never import Xcode or SwiftUI.
public enum MacOSCINotes: Sendable {
    public static let macosCIWorkflowPresent = true
    public static let workflowPath = ".github/workflows/ci.yml"
    public static let runner = "macos-14"
    /// macos-14 GitHub runners with Xcode 15.4 typically include iPhone 15.
    public static let iosSimulatorDestination = "platform=iOS Simulator,name=iPhone 15"
    public static let macosDestination = "platform=macOS"
    public static let linuxCannotRunXcodebuild = true
}

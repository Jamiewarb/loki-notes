import Foundation
import LociCore

/// CLI: macOS CI / shortcuts / VoiceOver / Dynamic Type proofs for DevHarness (PR39).
@main
struct LociMacOSCIDemo {
    struct Payload: Encodable {
        var indexInsideVault: Bool
        var proof: MacOSCIProof
        var shortcuts: [KeyboardShortcutSpec]
        var accessibilityIdentifiers: [String]
        var accessibilityLabels: [String: String]
        var dynamicType: [LociDynamicTypeRole]
        var workflowRunner: String
        var workflowPath: String
        var iosSimulatorDestination: String
        var macosDestination: String
        var linuxCannotRunXcodebuild: Bool
        var note: String
    }

    static func main() throws {
        let proof = MacOSCIProof.evaluate(indexInsideVault: false)
        let payload = Payload(
            indexInsideVault: false,
            proof: proof,
            shortcuts: KeyboardShortcutCatalog.all,
            accessibilityIdentifiers: LociAccessibilityCatalog.screenIdentifiers,
            accessibilityLabels: [
                LociAccessibilityCatalog.dailyNote: LociAccessibilityCatalog.dailyNoteLabel,
                LociAccessibilityCatalog.objectEditor: LociAccessibilityCatalog.objectEditorLabel,
                LociAccessibilityCatalog.search: LociAccessibilityCatalog.searchLabel,
                LociAccessibilityCatalog.settings: LociAccessibilityCatalog.settingsLabel,
            ],
            dynamicType: LociDynamicTypeCatalog.all,
            workflowRunner: MacOSCINotes.runner,
            workflowPath: MacOSCINotes.workflowPath,
            iosSimulatorDestination: MacOSCINotes.iosSimulatorDestination,
            macosDestination: MacOSCINotes.macosDestination,
            linuxCannotRunXcodebuild: MacOSCINotes.linuxCannotRunXcodebuild,
            note:
                "Linux cannot execute xcodebuild; YAML macos-14 job is the CI deliverable. Index never in vault."
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(payload)
        if let text = String(data: data, encoding: .utf8) {
            print(text)
        }
    }
}

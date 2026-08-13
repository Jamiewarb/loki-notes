import LociCore
import XCTest

final class KeyboardShortcutCatalogTests: XCTestCase {
    func testFourUniqueActions() {
        XCTAssertEqual(KeyboardShortcutCatalog.all.count, 4)
        XCTAssertTrue(KeyboardShortcutCatalog.actionIDsAreUnique)
        XCTAssertTrue(KeyboardShortcutCatalog.combosAreUnique)
        XCTAssertEqual(
            Set(KeyboardShortcutCatalog.actionIDs),
            ["newPage", "search", "goToday", "quickCapture"]
        )
    }

    func testSearchIsCommandK() {
        let search = KeyboardShortcutCatalog.search
        XCTAssertEqual(search.actionID, "search")
        XCTAssertEqual(search.key, "k")
        XCTAssertEqual(search.modifiers, "command")
        XCTAssertTrue(search.usesCommand)
        XCTAssertFalse(search.usesShift)
    }

    func testCaptureUsesCommandShiftN() {
        let capture = KeyboardShortcutCatalog.quickCapture
        XCTAssertEqual(capture.actionID, "quickCapture")
        XCTAssertEqual(capture.key, "n")
        XCTAssertEqual(capture.modifiers, "command+shift")
        XCTAssertTrue(capture.usesShift)
        XCTAssertTrue(capture.usesCommand)
        XCTAssertEqual(KeyboardShortcutCatalog.newPage.key, "n")
        XCTAssertEqual(KeyboardShortcutCatalog.newPage.modifiers, "command")
        XCTAssertNotEqual(capture.combo, KeyboardShortcutCatalog.newPage.combo)
    }
}

final class LociAccessibilityCatalogTests: XCTestCase {
    func testDailyEditorSearchSettingsIdentifiers() {
        XCTAssertTrue(LociAccessibilityCatalog.hasDailyEditorSearchSettings)
        XCTAssertTrue(LociAccessibilityCatalog.screenIdentifiersAreUnique)
        XCTAssertEqual(LociAccessibilityCatalog.dailyNote, "daily-note")
        XCTAssertEqual(LociAccessibilityCatalog.dailyNoteLabel, "Daily note")
        XCTAssertEqual(LociAccessibilityCatalog.objectEditor, "object-editor")
        XCTAssertEqual(LociAccessibilityCatalog.objectEditorLabel, "Object editor")
        XCTAssertEqual(LociAccessibilityCatalog.search, "search-destination")
        XCTAssertEqual(LociAccessibilityCatalog.searchLabel, "Search")
        XCTAssertEqual(LociAccessibilityCatalog.settings, "vault-settings")
        XCTAssertEqual(LociAccessibilityCatalog.settingsLabel, "Settings")
        XCTAssertEqual(LociAccessibilityCatalog.searchQuery, "search-query-field")
        XCTAssertEqual(LociAccessibilityCatalog.searchQueryLabel, "Query")
        XCTAssertEqual(LociAccessibilityCatalog.vaultPath, "vault-path-display")
    }
}

final class LociDynamicTypeCatalogTests: XCTestCase {
    func testRelativeToMapping() {
        XCTAssertTrue(LociDynamicTypeCatalog.usesRelativeTo)
        XCTAssertEqual(LociDynamicTypeCatalog.all.count, 8)
        XCTAssertEqual(LociDynamicTypeCatalog.textStyleName(forRole: "brand"), "largeTitle")
        XCTAssertEqual(LociDynamicTypeCatalog.textStyleName(forRole: "display"), "title")
        XCTAssertEqual(LociDynamicTypeCatalog.textStyleName(forRole: "title"), "title2")
        XCTAssertEqual(LociDynamicTypeCatalog.textStyleName(forRole: "headline"), "headline")
        XCTAssertEqual(LociDynamicTypeCatalog.textStyleName(forRole: "body"), "body")
        XCTAssertEqual(LociDynamicTypeCatalog.textStyleName(forRole: "callout"), "callout")
        XCTAssertEqual(LociDynamicTypeCatalog.textStyleName(forRole: "caption"), "caption")
        XCTAssertEqual(LociDynamicTypeCatalog.textStyleName(forRole: "overline"), "caption")
    }
}

final class MacOSCIProofTests: XCTestCase {
    func testEvaluateProofFlags() {
        let proof = MacOSCIProof.evaluate(indexInsideVault: false)
        XCTAssertTrue(proof.macosCIWorkflowPresent)
        XCTAssertTrue(proof.shortcutsCatalogued)
        XCTAssertTrue(proof.voiceOverLabelsPresent)
        XCTAssertTrue(proof.dynamicTypeScales)
        XCTAssertFalse(proof.indexInsideVault)
        XCTAssertEqual(MacOSCINotes.runner, "macos-14")
        XCTAssertTrue(MacOSCINotes.iosSimulatorDestination.contains("iPhone 15"))
        XCTAssertTrue(MacOSCINotes.linuxCannotRunXcodebuild)
    }
}

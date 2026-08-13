import XCTest
@testable import LociCore

final class AIHeuristicsTests: XCTestCase {
    private func request(
        action: AIAction,
        title: String = "Hello world",
        body: String = "First sentence. Second sentence. Third.",
        defs: [PropertyDef] = [],
        existing: [String: PropertyValue] = [:],
        lang: String? = nil
    ) -> AIRequest {
        AIRequest(
            action: action,
            objectID: ObjectID(),
            title: title,
            bodyMarkdown: body,
            propertyDefs: defs,
            existingProperties: existing,
            targetLanguage: lang
        )
    }

    func testSummarizeUsesTitleAndFirstTwoSentences() throws {
        let proposal = AIHeuristics.summarize(
            request(action: .summarize, title: "Meeting notes", body: "Alpha one. Beta two. Gamma three.")
        )
        XCTAssertEqual(proposal.action, .summarize)
        XCTAssertEqual(proposal.provider, .onDeviceHeuristics)
        XCTAssertFalse(proposal.uploaded)
        let summary = try XCTUnwrap(proposal.summary)
        XCTAssertTrue(summary.hasPrefix("Summary: "))
        XCTAssertTrue(summary.contains("Meeting notes"))
        XCTAssertTrue(summary.contains("Alpha one"))
        XCTAssertTrue(summary.contains("Beta two"))
        XCTAssertFalse(summary.contains("Gamma three"))
        XCTAssertTrue(proposal.notes.contains(where: { $0.contains("2 sentence") }))
    }

    func testRewriteStripsFillersAndCollapsesNewlines() throws {
        let body = "This is very really just important.\n\n\n\nNext line.   \n"
        let proposal = AIHeuristics.rewrite(request(action: .rewrite, body: body))
        let out = try XCTUnwrap(proposal.proposedBody)
        XCTAssertFalse(out.lowercased().contains("very "))
        XCTAssertFalse(out.lowercased().contains("really "))
        XCTAssertFalse(out.lowercased().contains("just "))
        XCTAssertFalse(out.contains("\n\n\n"))
        XCTAssertTrue(out.hasSuffix("\n"))
        XCTAssertTrue(out.contains("important"))
    }

    func testTranslateSpanishGlossary() throws {
        let proposal = AIHeuristics.translate(
            request(action: .translate, title: "", body: "hello world and the book today"),
            language: "es"
        )
        let out = try XCTUnwrap(proposal.proposedBody)
        XCTAssertTrue(out.hasPrefix("<!-- loci-ai:translated:es -->"))
        XCTAssertTrue(out.contains("hola"))
        XCTAssertTrue(out.contains("mundo"))
        XCTAssertTrue(out.contains("libro"))
        XCTAssertTrue(out.contains("hoy"))
        XCTAssertTrue(out.contains("el"))
        XCTAssertTrue(out.contains("y"))
    }

    func testTranslateFrenchGlossary() throws {
        let proposal = AIHeuristics.translate(
            request(action: .translate, body: "hello world book meeting today"),
            language: "fr"
        )
        let out = try XCTUnwrap(proposal.proposedBody)
        XCTAssertTrue(out.hasPrefix("<!-- loci-ai:translated:fr -->"))
        XCTAssertTrue(out.contains("bonjour"))
        XCTAssertTrue(out.contains("monde"))
        XCTAssertTrue(out.contains("livre"))
        XCTAssertTrue(out.contains("réunion"))
        XCTAssertTrue(out.contains("aujourd'hui"))
    }

    func testAutofillPropertyKinds() throws {
        let defs: [PropertyDef] = [
            PropertyDef(id: "url", name: "URL", kind: .url),
            PropertyDef(id: "when", name: "When", kind: .date),
            PropertyDef(id: "title", name: "Title", kind: .text),
            PropertyDef(id: "status", name: "Status", kind: .select, options: ["Draft", "Done"]),
            PropertyDef(id: "flags", name: "Flags", kind: .multiSelect, options: ["urgent", "review"]),
            PropertyDef(id: "done", name: "Done", kind: .checkbox),
            PropertyDef(id: "count", name: "Count", kind: .number),
            PropertyDef(id: "ref", name: "Ref", kind: .objectSelect),
        ]
        let body = """
        See https://example.com/a on 2024-06-15. Status Done and urgent review. Count is 42.
        Also #inbox #work complete.
        """
        let proposal = AIHeuristics.autofillProperties(
            request(action: .autofillProperties, title: "My Page", body: body, defs: defs)
        )
        let props = try XCTUnwrap(proposal.proposedProperties)
        XCTAssertEqual(props["url"], .url("https://example.com/a"))
        if case .date(let d)? = props["when"] {
            var cal = Calendar(identifier: .gregorian)
            cal.timeZone = TimeZone(secondsFromGMT: 0)!
            let c = cal.dateComponents([.year, .month, .day], from: d)
            XCTAssertEqual(c.year, 2024)
            XCTAssertEqual(c.month, 6)
            XCTAssertEqual(c.day, 15)
        } else {
            XCTFail("expected date")
        }
        XCTAssertEqual(props["title"], .text("My Page"))
        XCTAssertEqual(props["status"], .select("Done"))
        XCTAssertEqual(props["flags"], .multiSelect(["urgent", "review"]))
        XCTAssertEqual(props["done"], .bool(true))
        XCTAssertEqual(props["count"], .number(42))
        XCTAssertNil(props["ref"])
        XCTAssertTrue(proposal.notes.contains(where: { $0.contains("tags:") && $0.contains("inbox") }))
    }

    func testAutofillSkipsExistingNonNull() {
        let defs = [PropertyDef(id: "url", name: "URL", kind: .url)]
        let proposal = AIHeuristics.autofillProperties(
            request(
                action: .autofillProperties,
                body: "https://example.com",
                defs: defs,
                existing: ["url": .url("https://keep.me")]
            )
        )
        XCTAssertTrue(proposal.proposedProperties == nil || proposal.proposedProperties?.isEmpty == true)
    }

    func testPrivacyPayloadIsCurrentObjectOnly() {
        let req = request(
            action: .summarize,
            title: "Only This",
            body: "Body of current object."
        )
        let text = AIPrivacy.payloadText(request: req)
        XCTAssertTrue(text.contains("Only This"))
        XCTAssertTrue(text.contains("Body of current object."))
        XCTAssertFalse(text.contains("/vault"))
        XCTAssertFalse(text.contains("objects/"))
        XCTAssertFalse(text.contains("index.sqlite"))
        // Must not concatenate a vault directory listing.
        XCTAssertFalse(text.contains("daily/"))
    }

    func testRemotePayloadAllowedFalseByDefault() {
        let settings = AISettings()
        XCTAssertFalse(settings.uploadVaultOptIn)
        let req = request(action: .summarize)
        XCTAssertFalse(AIPrivacy.remotePayloadAllowed(settings: settings, request: req))

        let opted = AISettings(uploadVaultOptIn: true)
        XCTAssertFalse(
            AIPrivacy.remotePayloadAllowed(
                settings: opted,
                request: req
            )
        )
        var withAllow = req
        withAllow.allowRemoteUpload = true
        XCTAssertTrue(AIPrivacy.remotePayloadAllowed(settings: opted, request: withAllow))
    }

    func testSettingsDefaults() {
        let s = AISettings()
        XCTAssertEqual(s.preferredProvider, .onDeviceHeuristics)
        XCTAssertFalse(s.uploadVaultOptIn)
        XCTAssertEqual(s.targetLanguage, "es")
        XCTAssertNil(s.byokProviderName)
    }
}

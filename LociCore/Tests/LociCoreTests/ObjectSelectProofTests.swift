import LociCore
import XCTest

final class ObjectSelectProofTests: XCTestCase {
    func testPersistableStringLowercasesUUID() {
        let raw = "8F3C2A1E-0000-4000-8000-000000000001"
        XCTAssertEqual(
            ObjectSelectID.persistableString(from: raw),
            "8f3c2a1e-0000-4000-8000-000000000001"
        )
        XCTAssertTrue(ObjectSelectID.isObjectIDString(raw))
        XCTAssertFalse(ObjectSelectID.isObjectIDString("/tmp/vault/objects/book/x.md"))
        XCTAssertTrue(ObjectSelectID.looksLikeAbsolutePath("/tmp/vault/objects/book/x.md"))
        XCTAssertFalse(ObjectSelectID.looksLikeAbsolutePath("8f3c2a1e-0000-4000-8000-000000000001"))
    }

    func testParseListStripsWikiBracketsAndCommaDraft() {
        let ids = ObjectSelectID.parseList(
            "[[8F3C2A1E-0000-4000-8000-000000000001]],  bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb2"
        )
        XCTAssertEqual(
            ids,
            [
                "8f3c2a1e-0000-4000-8000-000000000001",
                "bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb2",
            ]
        )
        XCTAssertEqual(
            ObjectSelectID.draftString(from: ids),
            "8f3c2a1e-0000-4000-8000-000000000001, bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb2"
        )
    }

    func testEvaluateProofFlags() {
        let person = "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1"
        let yaml = """
            author:
              - \(person)
            """
        let proof = ObjectSelectProof.evaluate(
            storedIDs: [person],
            yamlSnippet: yaml,
            bodyMarkdown: "Cal Newport — focus is a skill.\n",
            candidateCount: 1,
            excludedObjectAppearsInCandidates: false,
            backlinkCount: 1,
            outgoingCount: 1,
            indexInsideVault: false
        )
        XCTAssertTrue(proof.pickerUsesIndexCandidates)
        XCTAssertTrue(proof.storesObjectIDs)
        XCTAssertTrue(proof.createsRealLinks)
        XCTAssertTrue(proof.doesNotRewriteBody)
        XCTAssertFalse(proof.indexInsideVault)
        XCTAssertTrue(ObjectSelectNotes.pickerUsesIndexCandidates)
        XCTAssertTrue(ObjectSelectNotes.propertiesMustNotImportLinks)
        XCTAssertEqual(ObjectSelectNotes.queryProtocol, "IndexQuerying.linkCandidates")
    }

    func testBodyWikiLinkFailsDoesNotRewriteBody() {
        let person = "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1"
        let proof = ObjectSelectProof.evaluate(
            storedIDs: [person],
            yamlSnippet: "author:\n  - \(person)\n",
            bodyMarkdown: "See [[\(person)]].\n",
            candidateCount: 1,
            excludedObjectAppearsInCandidates: false,
            backlinkCount: 1,
            outgoingCount: 1,
            indexInsideVault: false
        )
        XCTAssertFalse(proof.doesNotRewriteBody)
    }

    func testAbsolutePathFailsStoresObjectIDs() {
        let proof = ObjectSelectProof.evaluate(
            storedIDs: ["/tmp/vault/objects/person/cal.md"],
            yamlSnippet: "author:\n  - /tmp/vault/objects/person/cal.md\n",
            bodyMarkdown: "No wiki.\n",
            candidateCount: 1,
            excludedObjectAppearsInCandidates: false,
            backlinkCount: 1,
            outgoingCount: 1,
            indexInsideVault: false
        )
        XCTAssertFalse(proof.storesObjectIDs)
    }

    func testCoerceObjectSelectNormalizesUUIDs() {
        let value = PropertyValueFormatting.coerce(
            draft: "8F3C2A1E-0000-4000-8000-000000000001, missing-not-a-uuid",
            kind: .objectSelect
        )
        XCTAssertEqual(
            value,
            .objectSelect([
                "8f3c2a1e-0000-4000-8000-000000000001",
                "missing-not-a-uuid",
            ])
        )
    }
}

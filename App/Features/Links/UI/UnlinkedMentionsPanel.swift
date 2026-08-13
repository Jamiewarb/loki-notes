import SwiftUI
import LociCore
import LociDesignSystem

/// Inspector panel: unlinked title mentions (PR44). Derived from index + scanner —
/// never written into markdown unless the user taps **Link**.
struct UnlinkedMentionsPanel: View {
    var services: AppServices
    var objectID: ObjectID

    @State private var mentions: [UnlinkedMention] = []
    @State private var targetTitle = ""
    @State private var errorMessage: String?
    @State private var isLoading = false
    @State private var linkingID: String?

    var body: some View {
        VStack(alignment: .leading, spacing: LociSpacing.stack(.md)) {
            Text("Unlinked mentions")
                .font(LociTypography.font(.headline))
                .foregroundStyle(LociColors.ink)

            Text("Other notes that name this title in plain text, without a wiki-link. Scan only — not stored in markdown.")
                .font(LociTypography.font(.callout))
                .foregroundStyle(LociColors.inkSoft)
                .fixedSize(horizontal: false, vertical: true)

            if isLoading && mentions.isEmpty {
                ProgressView()
                    .controlSize(.small)
            } else if mentions.isEmpty {
                Text("No unlinked mentions.")
                    .font(LociTypography.font(.caption))
                    .foregroundStyle(LociColors.inkSoft)
                    .accessibilityIdentifier("unlinked-mentions-empty")
            } else {
                VStack(alignment: .leading, spacing: LociSpacing.stack(.sm)) {
                    ForEach(mentions, id: \.source.id.uuidString) { hit in
                        mentionRow(hit)
                    }
                }
                .accessibilityIdentifier("unlinked-mentions-list")
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(LociTypography.font(.caption))
                    .foregroundStyle(LociColors.danger)
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .padding(LociSpacing.stack(.lg))
        .task(id: objectID.uuidString) { await reload() }
        .accessibilityIdentifier("unlinked-mentions-panel")
    }

    @ViewBuilder
    private func mentionRow(_ hit: UnlinkedMention) -> some View {
        HStack(alignment: .top, spacing: LociSpacing.stack(.sm)) {
            Button {
                Task { await services.open(objectID: hit.source.id) }
            } label: {
                VStack(alignment: .leading, spacing: 2) {
                    Text(hit.source.title.isEmpty ? "Untitled" : hit.source.title)
                        .font(LociTypography.font(.callout))
                        .foregroundStyle(LociColors.ink)
                    if !hit.snippet.isEmpty {
                        Text(hit.snippet)
                            .font(LociTypography.font(.caption))
                            .foregroundStyle(LociColors.inkSoft)
                            .lineLimit(2)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 4)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier(
                "unlinked-mention-row-\(hit.source.id.uuidString.lowercased())"
            )

            Button("Link") {
                Task { await link(hit) }
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .disabled(linkingID != nil)
            .accessibilityIdentifier(
                "unlinked-mention-link-\(hit.source.id.uuidString.lowercased())"
            )
        }
    }

    private func reload() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let index = try await services.ensureIndex()
            if let meta = try await index.object(id: objectID) {
                targetTitle = meta.title
            }
            mentions = try await index.unlinkedMentions(to: objectID)
            errorMessage = nil
        } catch {
            mentions = []
            errorMessage = error.localizedDescription
        }
    }

    private func link(_ hit: UnlinkedMention) async {
        linkingID = hit.source.id.uuidString
        defer { linkingID = nil }
        do {
            _ = try await services.ensureIndex()
            guard let objects = services.objects else { return }
            let opened = try await objects.open(id: hit.source.id)
            let title = targetTitle.trimmingCharacters(in: .whitespacesAndNewlines)
            guard UnlinkedMentionScanner.isTitleScannable(title) else { return }
            let wiki = UnlinkedMentionScanner.wikiLinkMarkdown(
                targetID: objectID.frontMatterIDString,
                title: title
            )
            guard let next = UnlinkedMentionScanner.replaceFirst(
                in: opened.bodyMarkdown,
                title: title,
                withWikiLink: wiki
            ) else { return }
            try await objects.save(meta: opened.meta, bodyMarkdown: next)
            await reload()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

import SwiftUI
import LociCore
import LociDesignSystem

/// Cross-type tag index + tag page (PR17). Reads `IndexQuerying` only.
struct TagBrowseView: View {
    var services: AppServices

    @State private var tags: [TagSummary] = []
    @State private var objects: [LociObjectMeta] = []
    @State private var aliases = TagAliasTable.empty
    @State private var errorMessage: String?
    @State private var isBusy = false

    var body: some View {
        VStack(alignment: .leading, spacing: LociSpacing.stack(.lg)) {
            HStack(spacing: LociSpacing.stack(.md)) {
                if services.focusedTag != nil {
                    LociButton("← All tags", style: .secondary) {
                        services.focusedTag = nil
                        Task { await reload() }
                    }
                }
                Spacer(minLength: 0)
                LociButton("Refresh", style: .secondary) {
                    Task { await reload() }
                }
                .disabled(isBusy)
            }

            HStack(spacing: LociSpacing.stack(.md)) {
                LociIcon("number", size: 22)
                    .foregroundStyle(LociColors.accent)
                Text(headerTitle)
                    .font(LociTypography.font(.display))
                    .foregroundStyle(LociColors.ink)
            }
            .lociAppear(.soft)

            Text(headerBlurb)
                .font(LociTypography.font(.body))
                .foregroundStyle(LociColors.inkSoft)
                .frame(maxWidth: 520, alignment: .leading)

            if let focused = services.focusedTag {
                tagPage(focused)
            } else {
                allTagsList
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(LociTypography.font(.caption))
                    .foregroundStyle(LociColors.danger)
            }
        }
        .padding(LociSpacing.stack(.xl))
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .task(id: services.focusedTag ?? "") { await reload() }
        .accessibilityIdentifier("tag-browse")
    }

    private var headerTitle: String {
        if let focused = services.focusedTag {
            return TagNormalization.display(focused)
        }
        return "Tags"
    }

    private var headerBlurb: String {
        if services.focusedTag != nil {
            return "Objects across types that carry this tag (frontmatter or body #tag)."
        }
        return "Cross-type thematic keywords. Index projection only — never written as a derived list."
    }

    @ViewBuilder
    private var allTagsList: some View {
        if tags.isEmpty {
            LociEmptyState(
                title: "No tags yet",
                message: "Add #tags in the editor or object frontmatter.",
                systemImage: "number"
            )
        } else {
            VStack(alignment: .leading, spacing: LociSpacing.stack(.sm)) {
                ForEach(tags, id: \.tag) { summary in
                    Button {
                        Task { await services.openTag(summary.canonical) }
                    } label: {
                        HStack {
                            Text(summary.display)
                                .font(LociTypography.font(.headline))
                                .foregroundStyle(LociColors.accent)
                            Spacer(minLength: 0)
                            Text("\(summary.count)")
                                .font(LociTypography.font(.caption))
                                .foregroundStyle(LociColors.inkSoft)
                        }
                        .padding(.vertical, LociSpacing.stack(.sm))
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("tag-row-\(summary.tag)")
                }
            }
            .lociAppear(.soft)
        }
    }

    @ViewBuilder
    private func tagPage(_ tag: String) -> some View {
        Text("\(objects.count) object\(objects.count == 1 ? "" : "s")")
            .font(LociTypography.font(.overline))
            .tracking(0.08)
            .foregroundStyle(LociColors.inkSoft)

        if objects.isEmpty {
            LociEmptyState(
                title: "Nothing tagged \(TagNormalization.display(tag))",
                message: "Tag a Page and another type to see them here together.",
                systemImage: "number"
            )
        } else {
            VStack(alignment: .leading, spacing: LociSpacing.stack(.sm)) {
                ForEach(objects, id: \.id.uuidString) { item in
                    Button {
                        Task { await services.open(objectID: item.id) }
                    } label: {
                        HStack(alignment: .firstTextBaseline, spacing: LociSpacing.stack(.md)) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.title.isEmpty ? "Untitled" : item.title)
                                    .font(LociTypography.font(.headline))
                                    .foregroundStyle(LociColors.ink)
                                Text("\(item.typeID.rawValue) · \(item.relativePath)")
                                    .font(LociTypography.font(.caption))
                                    .foregroundStyle(LociColors.inkSoft)
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(.vertical, LociSpacing.stack(.sm))
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("tag-object-\(item.id.uuidString.lowercased())")
                }
            }
            .lociAppear(.soft)
        }
    }

    private func reload() async {
        isBusy = true
        defer { isBusy = false }
        do {
            let index = try await services.ensureIndex()
            if let space = try? await services.schema.loadSpaceSettings() {
                aliases = space.tagAliasTable
            } else {
                aliases = .empty
            }
            if let focused = services.focusedTag {
                objects = try await index.objects(
                    tagged: focused,
                    typeID: nil,
                    aliases: aliases
                )
                tags = []
            } else {
                tags = try await index.allTags(aliases: aliases, limit: 200)
                objects = []
            }
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

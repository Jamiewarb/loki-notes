import SwiftUI
import LociCore
import LociDesignSystem

/// `#` tag completer — searches via `IndexQuerying.tagCandidates`.
struct TagCompleterView: View {
    var services: AppServices
    var query: String
    var onSelect: (TagSummary) -> Void

    @State private var candidates: [TagSummary] = []
    @State private var errorMessage: String?
    @State private var isLoading = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(headerTitle)
                .font(LociTypography.font(.caption))
                .foregroundStyle(LociColors.inkSoft)
                .padding(.horizontal, LociSpacing.stack(.md))
                .padding(.vertical, LociSpacing.stack(.sm))

            if isLoading && candidates.isEmpty {
                ProgressView()
                    .controlSize(.small)
                    .padding(LociSpacing.stack(.md))
            } else if candidates.isEmpty {
                Text(query.isEmpty ? "No tags yet — type to create" : "No matches")
                    .font(LociTypography.font(.caption))
                    .foregroundStyle(LociColors.inkSoft)
                    .padding(LociSpacing.stack(.md))
            } else {
                ForEach(candidates, id: \.tag) { item in
                    Button {
                        onSelect(item)
                    } label: {
                        HStack(alignment: .firstTextBaseline, spacing: LociSpacing.stack(.sm)) {
                            Text(item.display)
                                .font(LociTypography.font(.body))
                                .foregroundStyle(LociColors.accent)
                            Spacer(minLength: 0)
                            if item.count > 0 {
                                Text("\(item.count)")
                                    .font(LociTypography.font(.caption))
                                    .foregroundStyle(LociColors.inkSoft)
                            } else {
                                Text("new")
                                    .font(LociTypography.font(.caption))
                                    .foregroundStyle(LociColors.inkSoft)
                            }
                        }
                        .padding(.horizontal, LociSpacing.stack(.md))
                        .padding(.vertical, LociSpacing.stack(.sm))
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("tag-completer-row-\(item.tag)")
                }
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(LociTypography.font(.caption))
                    .foregroundStyle(LociColors.danger)
                    .padding(LociSpacing.stack(.md))
            }
        }
        .frame(maxWidth: 320, alignment: .leading)
        .background(LociColors.panel)
        .clipShape(RoundedRectangle(cornerRadius: CGFloat(LociRadius.md), style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: CGFloat(LociRadius.md), style: .continuous)
                .stroke(LociColors.line, lineWidth: 1)
        )
        .task(id: query) { await reload() }
        .accessibilityIdentifier("tag-completer")
    }

    private var headerTitle: String {
        query.isEmpty ? "Insert tag" : "Tag · \(query)"
    }

    private func reload() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let index = try await services.ensureIndex()
            let aliases =
                (try? await services.schema.loadSpaceSettings())?.tagAliasTable ?? .empty
            candidates = try await index.tagCandidates(
                matching: query,
                aliases: aliases,
                limit: 12
            )
            errorMessage = nil
        } catch {
            candidates = []
            errorMessage = error.localizedDescription
        }
    }
}

import SwiftUI
import LociCore
import LociDesignSystem

/// `@` / `[[` object picker — searches titles via `IndexQuerying.linkCandidates`.
struct LinkPickerView: View {
    var services: AppServices
    var query: String
    var excluding: ObjectID?
    var onSelect: (LociObjectMeta) -> Void

    @State private var candidates: [LociObjectMeta] = []
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
                Text(query.isEmpty ? "No objects yet" : "No matches")
                    .font(LociTypography.font(.caption))
                    .foregroundStyle(LociColors.inkSoft)
                    .padding(LociSpacing.stack(.md))
            } else {
                ForEach(candidates, id: \.id.uuidString) { item in
                    Button {
                        onSelect(item)
                    } label: {
                        HStack(alignment: .firstTextBaseline, spacing: LociSpacing.stack(.sm)) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.title.isEmpty ? "Untitled" : item.title)
                                    .font(LociTypography.font(.body))
                                    .foregroundStyle(LociColors.ink)
                                Text("\(item.typeID.rawValue) · \(item.relativePath)")
                                    .font(LociTypography.font(.caption))
                                    .foregroundStyle(LociColors.inkSoft)
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(.horizontal, LociSpacing.stack(.md))
                        .padding(.vertical, LociSpacing.stack(.sm))
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier(
                        "link-picker-row-\(item.id.uuidString.lowercased())"
                    )
                }
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(LociTypography.font(.caption))
                    .foregroundStyle(LociColors.danger)
                    .padding(LociSpacing.stack(.md))
            }
        }
        .frame(maxWidth: 360, alignment: .leading)
        .background(LociColors.panel)
        .clipShape(RoundedRectangle(cornerRadius: CGFloat(LociRadius.md), style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: CGFloat(LociRadius.md), style: .continuous)
                .stroke(LociColors.line, lineWidth: 1)
        )
        .task(id: queryTaskID) { await reload() }
        .accessibilityIdentifier("link-picker")
    }

    private var headerTitle: String {
        query.isEmpty ? "Link to object" : "Link · \(query)"
    }

    private var queryTaskID: String {
        "\(query)|\(excluding?.uuidString.lowercased() ?? "")"
    }

    private func reload() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let index = try await services.ensureIndex()
            candidates = try await index.linkCandidates(
                matching: query,
                excluding: excluding,
                limit: 12
            )
            errorMessage = nil
        } catch {
            candidates = []
            errorMessage = error.localizedDescription
        }
    }
}

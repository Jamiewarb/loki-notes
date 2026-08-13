import SwiftUI
import LociCore
import LociDesignSystem

/// Lists Page objects from `IndexQuerying` (not a directory scrape).
struct PageListView: View {
    var services: AppServices
    @State private var pages: [LociObjectMeta] = []
    @State private var errorMessage: String?
    @State private var isBusy = false

    var body: some View {
        VStack(alignment: .leading, spacing: LociSpacing.stack(.lg)) {
            HStack(spacing: LociSpacing.stack(.md)) {
                LociIcon("doc.text", size: 22)
                    .foregroundStyle(LociColors.accent)
                Text("Pages")
                    .font(LociTypography.font(.display))
                    .foregroundStyle(LociColors.ink)
                Spacer(minLength: 0)
                LociButton("New Page", style: .primary) {
                    Task { await createPage() }
                }
                .disabled(isBusy)
            }
            .lociAppear(.soft)

            Text("Listed from the local index (`objects(typeID: .page)`). Vault files remain source of truth.")
                .font(LociTypography.font(.body))
                .foregroundStyle(LociColors.inkSoft)
                .frame(maxWidth: 520, alignment: .leading)

            if pages.isEmpty {
                LociEmptyState(
                    title: "No pages yet",
                    message: "Create a Page to write markdown under objects/page/.",
                    systemImage: "doc"
                )
            } else {
                VStack(alignment: .leading, spacing: LociSpacing.stack(.sm)) {
                    ForEach(pages, id: \.id.uuidString) { page in
                        Button {
                            Task { await services.open(objectID: page.id) }
                        } label: {
                            HStack(alignment: .firstTextBaseline, spacing: LociSpacing.stack(.md)) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(page.title.isEmpty ? "Untitled" : page.title)
                                        .font(LociTypography.font(.headline))
                                        .foregroundStyle(LociColors.ink)
                                    Text(page.relativePath)
                                        .font(LociTypography.font(.caption))
                                        .foregroundStyle(LociColors.inkSoft)
                                }
                                Spacer(minLength: 0)
                            }
                            .padding(.vertical, LociSpacing.stack(.sm))
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("page-row-\(page.id.uuidString.lowercased())")
                    }
                }
                .lociAppear(.soft)
            }

            LociButton("Refresh", style: .secondary) {
                Task { await reload() }
            }
            .disabled(isBusy)

            if let errorMessage {
                Text(errorMessage)
                    .font(LociTypography.font(.caption))
                    .foregroundStyle(LociColors.danger)
            }
        }
        .padding(LociSpacing.stack(.xl))
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .task { await reload() }
    }

    private func reload() async {
        isBusy = true
        defer { isBusy = false }
        do {
            _ = try await services.ensureIndex()
            pages = try await services.index?.objects(typeID: .page) ?? []
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func createPage() async {
        isBusy = true
        defer { isBusy = false }
        do {
            _ = try await services.createPage(title: "Untitled")
            await reload()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

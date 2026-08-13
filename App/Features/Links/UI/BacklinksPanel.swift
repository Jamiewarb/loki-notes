import SwiftUI
import LociCore
import LociDesignSystem

/// Inspector panel: backlinks from the disposable `links` index table (never written into markdown).
struct BacklinksPanel: View {
    var services: AppServices
    var objectID: ObjectID

    @State private var backlinks: [BacklinkRecord] = []
    @State private var outgoing: [ResolvedWikiLink] = []
    @State private var errorMessage: String?
    @State private var isLoading = false

    var body: some View {
        VStack(alignment: .leading, spacing: LociSpacing.stack(.md)) {
            Text("Backlinks")
                .font(LociTypography.font(.headline))
                .foregroundStyle(LociColors.ink)

            Text("Derived from the local links index — not stored in this object’s markdown.")
                .font(LociTypography.font(.callout))
                .foregroundStyle(LociColors.inkSoft)
                .fixedSize(horizontal: false, vertical: true)

            if isLoading && backlinks.isEmpty && outgoing.isEmpty {
                ProgressView()
                    .controlSize(.small)
            } else if backlinks.isEmpty {
                Text("No backlinks yet.")
                    .font(LociTypography.font(.caption))
                    .foregroundStyle(LociColors.inkSoft)
                    .accessibilityIdentifier("backlinks-empty")
            } else {
                VStack(alignment: .leading, spacing: LociSpacing.stack(.sm)) {
                    ForEach(backlinks, id: \.source.id.uuidString) { hit in
                        Button {
                            Task { await services.open(objectID: hit.source.id) }
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(hit.source.title.isEmpty ? "Untitled" : hit.source.title)
                                    .font(LociTypography.font(.callout))
                                    .foregroundStyle(LociColors.ink)
                                Text("\(hit.source.typeID.rawValue) · [[\(hit.target)]]")
                                    .font(LociTypography.font(.caption))
                                    .foregroundStyle(LociColors.inkSoft)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 4)
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier(
                            "backlink-row-\(hit.source.id.uuidString.lowercased())"
                        )
                    }
                }
                .accessibilityIdentifier("backlinks-list")
            }

            if !outgoing.isEmpty {
                LociDivider()

                Text("Outgoing")
                    .font(LociTypography.font(.overline))
                    .tracking(0.08)
                    .foregroundStyle(LociColors.inkSoft)

                VStack(alignment: .leading, spacing: LociSpacing.stack(.sm)) {
                    ForEach(Array(outgoing.enumerated()), id: \.offset) { _, link in
                        outgoingRow(link)
                    }
                }
                .accessibilityIdentifier("outgoing-links-list")
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
        .accessibilityIdentifier("backlinks-panel")
    }

    @ViewBuilder
    private func outgoingRow(_ link: ResolvedWikiLink) -> some View {
        let broken = link.isBroken
        Button {
            if let id = link.resolved?.id {
                Task { await services.open(objectID: id) }
            }
        } label: {
            HStack(alignment: .firstTextBaseline, spacing: LociSpacing.stack(.sm)) {
                Text(link.displayText)
                    .font(LociTypography.font(.callout))
                    .foregroundStyle(broken ? LociColors.danger : LociColors.accent)
                    .underline(broken, pattern: .dash)
                if broken {
                    Text("missing")
                        .font(LociTypography.font(.caption))
                        .foregroundStyle(LociColors.danger)
                }
                Spacer(minLength: 0)
            }
            .padding(.vertical, 2)
        }
        .buttonStyle(.plain)
        .disabled(broken)
        .accessibilityIdentifier(
            broken
                ? "outgoing-broken-\(link.target)"
                : "outgoing-ok-\(link.target)"
        )
    }

    private func reload() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let index = try await services.ensureIndex()
            async let backs = index.backlinks(to: objectID)
            async let outs = index.outgoingLinks(from: objectID)
            backlinks = try await backs
            outgoing = try await outs
            errorMessage = nil
        } catch {
            backlinks = []
            outgoing = []
            errorMessage = error.localizedDescription
        }
    }
}

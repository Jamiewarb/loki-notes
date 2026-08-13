import SwiftUI
import LociCore
import LociDesignSystem

/// Inspector card for weblink Open Graph metadata (PR43).
///
/// Title + description + image URL as text (Linux cannot show remote images
/// reliably). Fetch on appear / Refresh preview — never on editor typing.
struct WeblinkPreviewCard: View {
    var services: AppServices
    let objectID: ObjectID

    @State private var state = WeblinkPreviewState.hidden

    private var store: WeblinkPreviewStore {
        WeblinkPreviewStore(objects: services.objects, previews: services.linkPreviews)
    }

    var body: some View {
        Group {
            if state.isWeblink {
                cardBody
            }
        }
        .task(id: objectID.uuidString) { await reload() }
    }

    private var cardBody: some View {
        VStack(alignment: .leading, spacing: LociSpacing.stack(.md)) {
            Text("Link preview")
                .font(LociTypography.font(.overline))
                .tracking(0.08)
                .foregroundStyle(LociColors.inkSoft)

            if let preview = state.preview, preview.hasContent {
                Text(preview.title ?? "Untitled")
                    .font(LociTypography.font(.headline))
                    .foregroundStyle(LociColors.ink)
                    .fixedSize(horizontal: false, vertical: true)
                if let description = preview.description {
                    Text(description)
                        .font(LociTypography.font(.callout))
                        .foregroundStyle(LociColors.inkSoft)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if let image = preview.imageURL {
                    Text(image.absoluteString)
                        .font(LociTypography.font(.caption))
                        .foregroundStyle(LociColors.inkSoft)
                        .textSelection(.enabled)
                }
            } else {
                Text("No preview")
                    .font(LociTypography.font(.callout))
                    .foregroundStyle(LociColors.inkSoft)
            }

            if let url = state.sourceURL ?? state.preview?.sourceURL {
                Text(url.absoluteString)
                    .font(LociTypography.font(.caption))
                    .foregroundStyle(LociColors.accent)
                    .textSelection(.enabled)
            }

            LociButton("Refresh preview", style: .secondary) {
                Task { await refresh() }
            }

            Text(state.status)
                .font(LociTypography.font(.caption))
                .foregroundStyle(LociColors.inkSoft)

            Text("OG cache is Application Support only — never vault YAML.")
                .font(LociTypography.font(.caption))
                .foregroundStyle(LociColors.inkSoft)
        }
        .padding(LociSpacing.stack(.lg))
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(LociColors.panel.opacity(0.55))
        .lociAppear(.panel)
        .accessibilityIdentifier("weblink-preview-card")
        .accessibilityLabel("Link preview")
    }

    private func reload() async {
        state = await store.load(objectID: objectID)
    }

    private func refresh() async {
        guard let url = state.sourceURL else {
            await reload()
            return
        }
        let preview = await store.refresh(url: url)
        state.preview = preview
        state.status = preview.hasContent ? "Refreshed preview." : "No preview — placeholder."
    }
}

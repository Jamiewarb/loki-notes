import Foundation
import LociCore

/// Thin feature-local facade over `LinkPreviewServing` + `ObjectServing` (PR43).
///
/// Fetch on weblink open / Refresh preview. Never called from editor typing.
@MainActor
final class WeblinkPreviewStore {
    private let objects: (any ObjectServing)?
    private let previews: any LinkPreviewServing

    init(objects: (any ObjectServing)?, previews: any LinkPreviewServing) {
        self.objects = objects
        self.previews = previews
    }

    func load(objectID: ObjectID) async -> WeblinkPreviewState {
        guard let objects else {
            return WeblinkPreviewState.hidden
        }
        do {
            let opened = try await objects.open(id: objectID)
            guard opened.meta.typeID == .weblink else {
                return WeblinkPreviewState.hidden
            }
            guard let url = WeblinkURL.from(opened.meta) else {
                return WeblinkPreviewState(
                    isWeblink: true,
                    sourceURL: nil,
                    preview: nil,
                    status: "No http(s) url property — nothing to fetch."
                )
            }
            let preview = try await previews.preview(for: url)
            return WeblinkPreviewState(
                isWeblink: true,
                sourceURL: url,
                preview: preview,
                status: preview.hasContent ? "Cached preview." : "No preview — placeholder."
            )
        } catch {
            return WeblinkPreviewState(
                isWeblink: true,
                sourceURL: nil,
                preview: nil,
                status: "Preview unavailable."
            )
        }
    }

    func refresh(url: URL) async -> LinkPreview {
        (try? await previews.refresh(for: url)) ?? .placeholder(sourceURL: url)
    }
}

struct WeblinkPreviewState: Equatable, Sendable {
    var isWeblink: Bool
    var sourceURL: URL?
    var preview: LinkPreview?
    var status: String

    static let hidden = WeblinkPreviewState(
        isWeblink: false,
        sourceURL: nil,
        preview: nil,
        status: ""
    )
}

import SwiftUI
import LociCore
import LociDesignSystem

#if canImport(UniformTypeIdentifiers)
import UniformTypeIdentifiers
#endif

/// macOS Finder / image drop → `MediaServing.attach`. `#else` is a no-op so Linux App/ compiles.
struct MediaDropAttachModifier: ViewModifier {
    var services: AppServices
    var objectRelativePath: String
    var onInsertedMarkdown: (String) -> Void
    var onStatus: ((String) -> Void)? = nil

    @State private var isTargeted = false

    func body(content: Content) -> some View {
        #if os(macOS) && canImport(UniformTypeIdentifiers)
        content
            .onDrop(of: Self.dropTypes, isTargeted: $isTargeted) { providers in
                Task { await handleDrop(providers) }
                return true
            }
            .overlay {
                if isTargeted {
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(LociColors.accent, lineWidth: 2)
                }
            }
        #else
        content
        #endif
    }

    #if os(macOS) && canImport(UniformTypeIdentifiers)
    private static let dropTypes: [UTType] = [.fileURL, .image]

    private func handleDrop(_ providers: [NSItemProvider]) async {
        for provider in providers {
            if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier),
                let url = await loadFileURL(provider)
            {
                await attachDroppedFile(url)
                continue
            }
            if provider.hasItemConformingToTypeIdentifier(UTType.image.identifier),
                let data = await loadImageData(provider)
            {
                await attachDroppedData(data, preferredFileName: "drop.png")
            }
        }
    }

    private func attachDroppedFile(_ url: URL) async {
        do {
            let result = try await MediaAttachAction.attachFile(
                media: services.media,
                fileURL: url,
                objectRelativePath: objectRelativePath
            )
            if let markdown = result.markdown {
                onInsertedMarkdown(markdown)
            }
            onStatus?(
                "Saved \(result.attachment.relativePath) (\(result.attachment.byteCount) B)"
            )
        } catch {
            onStatus?(error.localizedDescription)
        }
    }

    private func attachDroppedData(_ data: Data, preferredFileName: String) async {
        do {
            let result = try await MediaAttachAction.attachData(
                media: services.media,
                data: data,
                kind: .image,
                preferredFileName: preferredFileName,
                alt: (preferredFileName as NSString).deletingPathExtension,
                objectRelativePath: objectRelativePath
            )
            onInsertedMarkdown(result.markdown)
            onStatus?(
                "Saved \(result.attachment.relativePath) (\(result.attachment.byteCount) B)"
            )
        } catch {
            onStatus?(error.localizedDescription)
        }
    }

    private func loadFileURL(_ provider: NSItemProvider) async -> URL? {
        await withCheckedContinuation { continuation in
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) {
                item,
                _ in
                if let url = item as? URL {
                    continuation.resume(returning: url)
                } else if let data = item as? Data,
                    let url = URL(dataRepresentation: data, relativeTo: nil)
                {
                    continuation.resume(returning: url)
                } else if let string = item as? String, let url = URL(string: string) {
                    continuation.resume(returning: url)
                } else {
                    continuation.resume(returning: nil)
                }
            }
        }
    }

    private func loadImageData(_ provider: NSItemProvider) async -> Data? {
        await withCheckedContinuation { continuation in
            provider.loadDataRepresentation(forTypeIdentifier: UTType.image.identifier) {
                data,
                _ in
                continuation.resume(returning: data)
            }
        }
    }
    #endif
}

#if !os(macOS)
/// Stub note: drag-drop is macOS-only. Linux / iOS use Photos or `attach(fileURL:)`.
enum MediaDropAttachUnavailable {}
#endif

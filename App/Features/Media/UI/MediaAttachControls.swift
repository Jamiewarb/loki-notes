import SwiftUI
import LociCore
import LociDesignSystem

#if canImport(PhotosUI)
import PhotosUI
#endif

/// Attach controls — PhotosPicker on iOS, drop on macOS, demo-byte buttons everywhere (Linux).
struct MediaAttachControls: View {
    var services: AppServices
    var objectRelativePath: String
    var onInsertedMarkdown: (String) -> Void

    @State private var status: String?
    @State private var isBusy = false

    #if canImport(PhotosUI) && os(iOS)
    @State private var showPhotosPicker = false
    @State private var photosSelection: PhotosPickerItem?
    #endif

    var body: some View {
        VStack(alignment: .leading, spacing: LociSpacing.stack(.sm)) {
            HStack(spacing: LociSpacing.stack(.sm)) {
                LociButton("Attach image", style: .secondary) {
                    Task { await attachDemoImage() }
                }
                .disabled(isBusy)

                LociButton("Attach file", style: .secondary) {
                    Task { await attachDemoFile() }
                }
                .disabled(isBusy)

                #if canImport(PhotosUI) && os(iOS)
                LociButton("Photos…", style: .secondary) {
                    showPhotosPicker = true
                }
                .disabled(isBusy)
                .photosPicker(
                    isPresented: $showPhotosPicker,
                    selection: $photosSelection,
                    matching: .images
                )
                .onChange(of: photosSelection) { _, item in
                    Task { await attachPhotosItem(item) }
                }
                #endif

                #if os(macOS)
                Text("Drop files onto the editor")
                    .font(LociTypography.font(.caption))
                    .foregroundStyle(LociColors.inkSoft)
                #endif
            }

            if let status {
                Text(status)
                    .font(LociTypography.font(.caption))
                    .foregroundStyle(LociColors.inkSoft)
                    .accessibilityIdentifier("media-attach-status")
            }
        }
        .accessibilityIdentifier("media-attach-controls")
        .modifier(
            MediaDropAttachModifier(
                services: services,
                objectRelativePath: objectRelativePath,
                onInsertedMarkdown: onInsertedMarkdown,
                onStatus: { status = $0 }
            )
        )
    }

    /// Deterministic PNG-ish bytes for simulator / local fallback without a real picker.
    private func attachDemoImage() async {
        isBusy = true
        defer { isBusy = false }
        do {
            let bytes = Data("PNG-DEMO-\(UUID().uuidString.prefix(8))".utf8)
            let result = try await MediaAttachAction.attachData(
                media: services.media,
                data: bytes,
                kind: .image,
                preferredFileName: "demo.png",
                alt: "demo",
                objectRelativePath: objectRelativePath
            )
            onInsertedMarkdown(result.markdown)
            status = "Saved \(result.attachment.relativePath) (\(result.attachment.byteCount) B)"
        } catch {
            status = error.localizedDescription
        }
    }

    private func attachDemoFile() async {
        isBusy = true
        defer { isBusy = false }
        do {
            let bytes = Data("FILE-DEMO".utf8)
            let attachment = try await services.media.attach(
                data: bytes,
                kind: .file,
                preferredFileName: "notes.txt"
            )
            status = "Saved \(attachment.relativePath) (\(attachment.byteCount) B)"
        } catch {
            status = error.localizedDescription
        }
    }

    #if canImport(PhotosUI) && os(iOS)
    private func attachPhotosItem(_ item: PhotosPickerItem?) async {
        guard let item else { return }
        isBusy = true
        defer { isBusy = false }
        do {
            guard let data = try await item.loadTransferable(type: Data.self) else {
                status = "Could not load photo data"
                return
            }
            let name = suggestedPhotoFileName(item)
            let result = try await MediaAttachAction.attachData(
                media: services.media,
                data: data,
                kind: .image,
                preferredFileName: name,
                alt: (name as NSString).deletingPathExtension,
                objectRelativePath: objectRelativePath
            )
            onInsertedMarkdown(result.markdown)
            status = "Saved \(result.attachment.relativePath) (\(result.attachment.byteCount) B)"
        } catch {
            status = error.localizedDescription
        }
        photosSelection = nil
    }

    private func suggestedPhotoFileName(_ item: PhotosPickerItem) -> String {
        if let type = item.supportedContentTypes.first {
            let ext = type.preferredFilenameExtension ?? "jpg"
            return "photo.\(ext)"
        }
        return "photo.jpg"
    }
    #endif
}

#if !canImport(PhotosUI)
/// PhotosPicker is Apple-only. Linux / tests use `MediaServing.attach(fileURL:)`.
enum MediaPhotosPickerStub {}
#endif

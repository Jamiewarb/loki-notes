import SwiftUI
import LociCore
import LociDesignSystem

/// Attach controls — PhotosPicker / file importer stubs on Apple; Linux uses MediaServing APIs.
struct MediaAttachControls: View {
    var services: AppServices
    var objectRelativePath: String
    var onInsertedMarkdown: (String) -> Void

    @State private var status: String?
    @State private var isBusy = false

#if os(iOS)
    // PhotosUI available on iOS — stub entry until full picker wiring.
    @State private var showPhotosStub = false
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

#if os(iOS)
                LociButton("Photos…", style: .secondary) {
                    showPhotosStub = true
                    status = "Photos picker stub — use Attach image / MediaServing on Linux."
                }
#endif

#if os(macOS)
                Text("Drop files onto the editor (stub)")
                    .font(LociTypography.font(.caption))
                    .foregroundStyle(LociColors.inkSoft)
#endif
            }

            if let status {
                Text(status)
                    .font(LociTypography.font(.caption))
                    .foregroundStyle(LociColors.inkSoft)
            }
        }
        .accessibilityIdentifier("media-attach-controls")
    }

    /// Deterministic PNG-ish bytes for simulator / local fallback without a real picker.
    private func attachDemoImage() async {
        isBusy = true
        defer { isBusy = false }
        do {
            let bytes = Data("PNG-DEMO-\(UUID().uuidString.prefix(8))".utf8)
            let attachment = try await services.media.attach(
                data: bytes,
                kind: .image,
                preferredFileName: "demo.png"
            )
            let line = MediaInserter.markdownLine(
                alt: "demo",
                attachment: attachment,
                fromObjectRelativePath: objectRelativePath
            )
            onInsertedMarkdown(line)
            status = "Saved \(attachment.relativePath) (\(attachment.byteCount) B)"
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
}

import SwiftUI
import LociCore
import LociDesignSystem

/// Host for title + BlockEditor body (PR09). BlockAST owned by EditorSession via bridge.
struct ObjectEditorView: View {
    var services: AppServices
    let objectID: ObjectID

    @State private var session: EditorSessionBridge?
    @State private var errorMessage: String?
    @State private var isLoading = true

    var body: some View {
        Group {
            if let session {
                editorBody(session)
            } else if isLoading {
                ProgressView("Opening…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            } else {
                LociEmptyState(
                    title: "Could not open",
                    message: errorMessage ?? "Object missing from index or vault.",
                    systemImage: "doc"
                )
                .padding(LociSpacing.stack(.xl))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .task(id: objectID.uuidString) { await load() }
    }

    @ViewBuilder
    private func editorBody(_ session: EditorSessionBridge) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: LociSpacing.stack(.md)) {
                HStack(spacing: LociSpacing.stack(.sm)) {
                    TextField(
                        "Title",
                        text: Binding(
                            get: { session.title },
                            set: { session.applyTitle($0) }
                        )
                    )
                    .font(LociTypography.font(.display))
                    .foregroundStyle(LociColors.ink)
                    .textFieldStyle(.plain)

                    if session.isDirty {
                        Text(session.isSaving ? "Saving…" : "Edited")
                            .font(LociTypography.font(.caption))
                            .foregroundStyle(LociColors.inkSoft)
                    }
                }

                Text(session.relativePath)
                    .font(LociTypography.font(.caption))
                    .foregroundStyle(LociColors.inkSoft)

                BlockEditorFeature.editor(session: session)

                HStack(spacing: LociSpacing.stack(.md)) {
                    LociButton("Save now", style: .secondary) {
                        Task { await session.flushSave() }
                    }
                    LociButton("Delete", style: .secondary) {
                        Task { await deleteObject() }
                    }
                    Spacer(minLength: 0)
                }

                if let err = session.lastError ?? errorMessage {
                    Text(err)
                        .font(LociTypography.font(.caption))
                        .foregroundStyle(LociColors.danger)
                }

                Text(
                    "Block editor · / slash menu · autosave 500ms (max 5s). Index updates after save."
                )
                .font(LociTypography.font(.caption))
                .foregroundStyle(LociColors.inkSoft)
            }
            .padding(LociSpacing.stack(.xl))
        }
        .accessibilityIdentifier("object-editor")
    }

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let objects = try await services.ensureObjectService()
            let opened = try await objects.open(id: objectID)
            session = try EditorSessionBridge(opened: opened, objects: objects)
            errorMessage = nil
        } catch {
            session = nil
            errorMessage = error.localizedDescription
        }
    }

    private func deleteObject() async {
        do {
            if let session {
                await session.flushSave()
            }
            let objects = try await services.ensureObjectService()
            try await objects.delete(id: objectID)
            await services.open(route: .types)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

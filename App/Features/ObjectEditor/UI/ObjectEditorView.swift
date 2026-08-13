import SwiftUI
import LociCore
import LociDesignSystem

/// Host for title + plain-text body (PR08). Full BlockEditor arrives in PR09.
struct ObjectEditorView: View {
    var services: AppServices
    let objectID: ObjectID

    @State private var session: ObjectEditorSession?
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
    private func editorBody(_ session: ObjectEditorSession) -> some View {
        VStack(alignment: .leading, spacing: LociSpacing.stack(.md)) {
            HStack(spacing: LociSpacing.stack(.sm)) {
                TextField("Title", text: Binding(
                    get: { session.title },
                    set: { session.applyTitle($0) }
                ))
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

            TextEditor(text: Binding(
                get: { session.bodyMarkdown },
                set: { session.applyBody($0) }
            ))
            .font(LociTypography.font(.body))
            .scrollContentBackground(.hidden)
            .frame(maxWidth: .infinity, minHeight: 240, maxHeight: .infinity, alignment: .topLeading)

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

            Text("Autosave is debounced (500ms). Block editor + slash menu land in PR09.")
                .font(LociTypography.font(.caption))
                .foregroundStyle(LociColors.inkSoft)
        }
        .padding(LociSpacing.stack(.xl))
        .accessibilityIdentifier("object-editor")
    }

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let objects = try await services.ensureObjectService()
            let opened = try await objects.open(id: objectID)
            session = ObjectEditorSession(opened: opened, objects: objects)
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

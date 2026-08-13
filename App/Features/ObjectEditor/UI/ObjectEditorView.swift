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
    @State private var showConvert = false

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
        .sheet(isPresented: $showConvert) {
            NavigationStack {
                TypeConversionFeature.sheet(services: services, objectID: objectID)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Done") { showConvert = false }
                        }
                    }
            }
            #if os(macOS)
            .frame(minWidth: 420, minHeight: 480)
            #endif
        }
        .onDisappear {
            if services.activeEditorSession?.objectID == objectID {
                services.activeEditorSession = nil
            }
        }
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
                    .accessibilityLabel(LociAccessibilityCatalog.editorTitleLabel)
                    .accessibilityIdentifier(LociAccessibilityCatalog.editorTitle)

                    if session.isDirty {
                        Text(session.isSaving ? "Saving…" : "Edited")
                            .font(LociTypography.font(.caption))
                            .foregroundStyle(LociColors.inkSoft)
                    }
                }

                Text(session.relativePath)
                    .font(LociTypography.font(.caption))
                    .foregroundStyle(LociColors.inkSoft)

                BlockEditorFeature.editor(session: session, services: services)

                MediaFeature.attachControls(
                    services: services,
                    objectRelativePath: session.relativePath
                ) { line in
                    session.insertMarkdownImageLine(line)
                }

                HStack(spacing: LociSpacing.stack(.md)) {
                    LociButton("Save now", style: .secondary) {
                        Task { await session.flushSave() }
                    }
                    LociButton("Convert type…", style: .secondary) {
                        showConvert = true
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
                    "Block editor · / slash (table · toggle · callout · mermaid) · Turn into… · @ / [[ link · # tags · media · autosave 500ms."
                )
                .font(LociTypography.font(.caption))
                .foregroundStyle(LociColors.inkSoft)
            }
            .padding(LociSpacing.stack(.xl))
        }
        .accessibilityIdentifier(LociAccessibilityCatalog.objectEditor)
        .accessibilityLabel(LociAccessibilityCatalog.objectEditorLabel)
        .modifier(
            MediaFeature.dropAttachModifier(
                services: services,
                objectRelativePath: session.relativePath
            ) { line in
                session.insertMarkdownImageLine(line)
            }
        )
    }

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let objects = try await services.ensureObjectService()
            let opened = try await objects.open(id: objectID)
            let bridge = try EditorSessionBridge(opened: opened, objects: objects)
            session = bridge
            services.activeEditorSession = bridge
            errorMessage = nil
        } catch {
            session = nil
            services.activeEditorSession = nil
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

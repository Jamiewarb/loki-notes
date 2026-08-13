import SwiftUI
import LociCore
import LociDesignSystem

/// Daily destination — day switcher + BlockEditor for `daily/YYYY-MM-DD.md`.
///
/// iOS launch prefers this route (`AppServices.selectedRoute` defaults to `.daily`).
/// Created-today inspector is PR11 — this view never rewrites the daily body for other creates.
struct DailyNoteView: View {
    var services: AppServices

    @State private var selectedDay: Date = DailyNoteIdentity.startOfDay(Date())
    @State private var session: EditorSessionBridge?
    @State private var errorMessage: String?
    @State private var isLoading = true
    @State private var pathLabel: String = ""

    private var calendar: Calendar { .current }

    var body: some View {
        Group {
            if let session {
                editorBody(session)
            } else if isLoading {
                ProgressView("Opening daily note…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            } else {
                LociEmptyState(
                    title: "Daily note unavailable",
                    message: errorMessage
                        ?? "Create a vault in Settings (local Documents fallback works without iCloud).",
                    systemImage: Route.daily.systemImage
                )
                .padding(LociSpacing.stack(.xl))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .task(id: dayTaskID) { await loadSelectedDay() }
    }

    private var dayTaskID: String {
        DailyNoteIdentity.dateKey(for: selectedDay, calendar: calendar)
    }

    @ViewBuilder
    private func editorBody(_ session: EditorSessionBridge) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: LociSpacing.stack(.md)) {
                HStack(spacing: LociSpacing.stack(.md)) {
                    LociIcon(Route.daily.systemImage, size: 22)
                        .foregroundStyle(LociColors.accent)
                    Text("Daily")
                        .font(LociTypography.font(.display))
                        .foregroundStyle(LociColors.ink)
                    Spacer(minLength: 0)
                    if session.isDirty {
                        Text(session.isSaving ? "Saving…" : "Edited")
                            .font(LociTypography.font(.caption))
                            .foregroundStyle(LociColors.inkSoft)
                    }
                }
                .lociAppear(.soft)

                DaySwitcher(selectedDay: $selectedDay, calendar: calendar)

                Text(pathLabel)
                    .font(LociTypography.font(.caption))
                    .foregroundStyle(LociColors.inkSoft)
                    .accessibilityIdentifier("daily-path")

                TextField(
                    "Title",
                    text: Binding(
                        get: { session.title },
                        set: { session.applyTitle($0) }
                    )
                )
                .font(LociTypography.font(.headline))
                .foregroundStyle(LociColors.ink)
                .textFieldStyle(.plain)

                BlockEditorFeature.editor(session: session)

                HStack(spacing: LociSpacing.stack(.md)) {
                    LociButton("Save now", style: .secondary) {
                        Task { await session.flushSave() }
                    }
                    Spacer(minLength: 0)
                }

                if let err = session.lastError ?? errorMessage {
                    Text(err)
                        .font(LociTypography.font(.caption))
                        .foregroundStyle(LociColors.danger)
                }

                Text(
                    "Path \(pathLabel) · id \(session.objectID.frontMatterIDString). Created-today panel is PR11 (inspector only)."
                )
                .font(LociTypography.font(.caption))
                .foregroundStyle(LociColors.inkSoft)
            }
            .padding(LociSpacing.stack(.xl))
        }
        .accessibilityIdentifier("daily-note-editor")
    }

    private func loadSelectedDay() async {
        isLoading = true
        defer { isLoading = false }
        do {
            // Prefer Daily on launch: ensure vault + index, then today’s (or selected) note.
            try await services.openVaultPipeline(rebuildIfNeeded: true)
            let notes = try await services.ensureDailyNoteService()
            let opened = try await notes.ensure(for: selectedDay, calendar: calendar)
            let objects = try await services.ensureObjectService()
            session = try EditorSessionBridge(opened: opened, objects: objects)
            pathLabel = opened.meta.relativePath
            errorMessage = nil
        } catch {
            session = nil
            pathLabel = ""
            errorMessage = error.localizedDescription
        }
    }
}

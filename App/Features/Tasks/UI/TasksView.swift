import SwiftUI
import LociCore
import LociDesignSystem
import LociMarkdown

/// Today / Open tasks destination. Index projection + optional vault write on toggle.
struct TasksView: View {
    var services: AppServices

    enum Scope: String, CaseIterable, Identifiable {
        case today
        case open

        var id: String { rawValue }
        var title: String {
            switch self {
            case .today: return "Today"
            case .open: return "Open"
            }
        }
    }

    @State private var scope: Scope = .today
    @State private var tasks: [IndexedTask] = []
    @State private var errorMessage: String?
    @State private var isLoading = false
    @State private var reloadNonce = 0

    var body: some View {
        VStack(alignment: .leading, spacing: LociSpacing.stack(.lg)) {
            HStack(spacing: LociSpacing.stack(.md)) {
                LociIcon(Route.tasks.systemImage, size: 22)
                    .foregroundStyle(LociColors.accent)
                Text(Route.tasks.title)
                    .font(LociTypography.font(.display))
                    .foregroundStyle(LociColors.ink)
                Spacer(minLength: 0)
            }
            .lociAppear(.soft)

            Text(
                "Today = tasks in today’s daily note. Open = incomplete tasks across the vault. Index only — never auto-written into markdown."
            )
            .font(LociTypography.font(.body))
            .foregroundStyle(LociColors.inkSoft)
            .frame(maxWidth: 560, alignment: .leading)

            Picker("Scope", selection: $scope) {
                ForEach(Scope.allCases) { s in
                    Text(s.title).tag(s)
                }
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("tasks-scope-picker")

            listBody

            if let errorMessage {
                Text(errorMessage)
                    .font(LociTypography.font(.caption))
                    .foregroundStyle(LociColors.danger)
            }
        }
        .padding(LociSpacing.stack(.xl))
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .task(id: "\(scope.rawValue)-\(reloadNonce)") { await reload() }
        .accessibilityIdentifier("tasks-destination")
    }

    @ViewBuilder
    private var listBody: some View {
        if isLoading && tasks.isEmpty {
            ProgressView()
                .controlSize(.small)
        } else if tasks.isEmpty {
            Text(emptyCopy)
                .font(LociTypography.font(.callout))
                .foregroundStyle(LociColors.inkSoft)
                .accessibilityIdentifier("tasks-empty")
        } else {
            VStack(alignment: .leading, spacing: LociSpacing.stack(.sm)) {
                ForEach(tasks) { task in
                    TaskRowView(
                        task: task,
                        showSource: scope == .open,
                        onToggle: { await toggle(task) },
                        onOpen: { await services.open(objectID: task.objectID) }
                    )
                }
            }
            .accessibilityIdentifier("tasks-list")
        }
    }

    private var emptyCopy: String {
        switch scope {
        case .today: return "No tasks on today’s daily note yet. Add `- [ ]` items or use /task."
        case .open: return "No open tasks. Incomplete checkboxes anywhere in the vault appear here."
        }
    }

    private func reload() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let index = try await services.ensureIndex()
            let cal = Calendar.current
            let day = DailyNoteIdentity.startOfDay(Date(), calendar: cal)
            switch scope {
            case .today:
                tasks = TaskAggregation.sorted(
                    try await index.tasks(inDailyNoteOn: day, calendar: cal)
                )
            case .open:
                tasks = TaskAggregation.sorted(try await index.openTasks())
            }
            errorMessage = nil
        } catch {
            tasks = []
            errorMessage = error.localizedDescription
        }
    }

    private func toggle(_ task: IndexedTask) async {
        do {
            let objects = try await services.ensureObjectService()
            let opened = try await objects.open(id: task.objectID)
            let nextBody = try TaskBodyEdits.toggle(
                bodyMarkdown: opened.bodyMarkdown,
                blockIndex: task.blockIndex,
                itemIndex: task.itemIndex
            )
            try await objects.save(meta: opened.meta, bodyMarkdown: nextBody)
            reloadNonce &+= 1
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct TaskRowView: View {
    let task: IndexedTask
    var showSource: Bool
    let onToggle: () async -> Void
    let onOpen: () async -> Void

    var body: some View {
        HStack(alignment: .top, spacing: LociSpacing.stack(.sm)) {
            Button {
                Task { await onToggle() }
            } label: {
                Image(systemName: task.isCompleted ? "checkmark.square.fill" : "square")
                    .foregroundStyle(LociColors.accent)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(task.isCompleted ? "Mark incomplete" : "Mark complete")
            .accessibilityIdentifier("task-toggle-\(task.id)")

            Button {
                Task { await onOpen() }
            } label: {
                VStack(alignment: .leading, spacing: 2) {
                    Text(task.text.isEmpty ? "Untitled task" : task.text)
                        .font(LociTypography.font(.callout))
                        .foregroundStyle(LociColors.ink)
                        .strikethrough(task.isCompleted)
                    if showSource {
                        Text(
                            "\(task.objectTitle.isEmpty ? "Untitled" : task.objectTitle) · \(task.relativePath)"
                        )
                        .font(LociTypography.font(.caption))
                        .foregroundStyle(LociColors.inkSoft)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
        .accessibilityIdentifier("task-row-\(task.id)")
    }
}

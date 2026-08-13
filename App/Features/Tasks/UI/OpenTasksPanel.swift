import SwiftUI
import LociCore
import LociDesignSystem
import LociMarkdown

/// Daily inspector: open tasks for the inspected day (from that day’s daily note).
///
/// **Source:** `IndexQuerying.tasks(inDailyNoteOn:)` — never writes derived lists into the daily .md.
struct OpenTasksPanel: View {
    var services: AppServices
    var day: Date
    var calendar: Calendar = .current

    @State private var tasks: [IndexedTask] = []
    @State private var openElsewhereCount = 0
    @State private var errorMessage: String?
    @State private var isLoading = false
    @State private var reloadNonce = 0

    var body: some View {
        VStack(alignment: .leading, spacing: LociSpacing.stack(.md)) {
            Text("Open tasks")
                .font(LociTypography.font(.headline))
                .foregroundStyle(LociColors.ink)

            Text(
                "Incomplete tasks on \(dayLabel)’s daily note. Toggle persists via ObjectServing.save → index."
            )
            .font(LociTypography.font(.callout))
            .foregroundStyle(LociColors.inkSoft)
            .fixedSize(horizontal: false, vertical: true)

            if isLoading && tasks.isEmpty {
                ProgressView()
                    .controlSize(.small)
            } else if tasks.isEmpty {
                Text("No open tasks on this daily note.")
                    .font(LociTypography.font(.caption))
                    .foregroundStyle(LociColors.inkSoft)
                    .accessibilityIdentifier("open-tasks-empty")
            } else {
                VStack(alignment: .leading, spacing: LociSpacing.stack(.sm)) {
                    ForEach(tasks) { task in
                        HStack(alignment: .top, spacing: LociSpacing.stack(.sm)) {
                            Button {
                                Task { await toggle(task) }
                            } label: {
                                Image(systemName: "square")
                                    .foregroundStyle(LociColors.accent)
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("open-task-toggle-\(task.id)")

                            Button {
                                Task { await services.open(objectID: task.objectID) }
                            } label: {
                                Text(task.text.isEmpty ? "Untitled task" : task.text)
                                    .font(LociTypography.font(.callout))
                                    .foregroundStyle(LociColors.ink)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .buttonStyle(.plain)
                        }
                        .accessibilityIdentifier("open-task-row-\(task.id)")
                    }
                }
                .accessibilityIdentifier("open-tasks-list")
            }

            if openElsewhereCount > 0 {
                Button {
                    Task { await services.open(route: .tasks) }
                } label: {
                    Text(
                        "\(openElsewhereCount) more open task\(openElsewhereCount == 1 ? "" : "s") elsewhere →"
                    )
                    .font(LociTypography.font(.caption))
                    .foregroundStyle(LociColors.accent)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("open-tasks-elsewhere")
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(LociTypography.font(.caption))
                    .foregroundStyle(LociColors.danger)
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .task(id: "\(dayTaskID)-\(reloadNonce)") { await reload() }
        .accessibilityIdentifier("open-tasks-panel")
    }

    private var dayTaskID: String {
        DailyNoteIdentity.dateKey(for: day, calendar: calendar)
    }

    private var dayLabel: String {
        DailyNoteIdentity.title(for: day, calendar: calendar)
    }

    private func reload() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let index = try await services.ensureIndex()
            let dayTasks = try await index.tasks(inDailyNoteOn: day, calendar: calendar)
            tasks = TaskAggregation.sorted(TaskAggregation.open(dayTasks))
            let allOpen = try await index.openTasks()
            let dayIDs = Set(tasks.map(\.id))
            openElsewhereCount = allOpen.filter { !dayIDs.contains($0.id) }.count
            errorMessage = nil
        } catch {
            tasks = []
            openElsewhereCount = 0
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

import SwiftUI
import LociCore
import LociDesignSystem

/// Inspector object-select control. Queries `IndexQuerying.linkCandidates` via
/// `ObjectSelectStore` — does **not** import `App/Features/Links`.
///
/// Selected values are ObjectID strings (lowercase UUID / daily key), never
/// absolute disk paths. Picker I/O is async so typing in the editor body is
/// never blocked on index or network.
struct ObjectSelectPickerView: View {
    var services: AppServices
    var excluding: ObjectID?
    @Binding var selectedIDs: [String]
    var onChange: () -> Void

    @State private var query = ""
    @State private var candidates: [LociObjectMeta] = []
    @State private var chipMetas: [String: LociObjectMeta] = [:]
    @State private var errorMessage: String?
    @State private var isLoading = false

    var body: some View {
        VStack(alignment: .leading, spacing: LociSpacing.stack(.sm)) {
            if !selectedIDs.isEmpty {
                VStack(alignment: .leading, spacing: LociSpacing.stack(.xs)) {
                    ForEach(selectedIDs, id: \.self) { id in
                        chip(for: id)
                    }
                }
            }

            TextField("Search objects", text: $query)
                .textFieldStyle(.roundedBorder)
                .font(LociTypography.font(.body))
                .accessibilityIdentifier("object-select-search")

            candidateList

            if let errorMessage {
                Text(errorMessage)
                    .font(LociTypography.font(.caption))
                    .foregroundStyle(LociColors.danger)
            }
        }
        .accessibilityIdentifier("object-select-picker")
        .task(id: queryTaskID) { await reloadCandidates() }
        .task(id: selectedIDs.joined(separator: ",")) { await reloadChips() }
    }

    @ViewBuilder
    private var candidateList: some View {
        if isLoading && candidates.isEmpty {
            ProgressView()
                .controlSize(.small)
        } else if visibleCandidates.isEmpty {
            Text(query.isEmpty ? "No objects yet" : "No matches")
                .font(LociTypography.font(.caption))
                .foregroundStyle(LociColors.inkSoft)
        } else {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(visibleCandidates, id: \.id.uuidString) { item in
                    Button {
                        add(item)
                    } label: {
                        HStack(alignment: .firstTextBaseline, spacing: LociSpacing.stack(.sm)) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.title.isEmpty ? "Untitled" : item.title)
                                    .font(LociTypography.font(.body))
                                    .foregroundStyle(LociColors.ink)
                                Text("\(item.typeID.rawValue) · \(item.relativePath)")
                                    .font(LociTypography.font(.caption))
                                    .foregroundStyle(LociColors.inkSoft)
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(.vertical, LociSpacing.stack(.xs))
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier(
                        "object-select-row-\(item.id.frontMatterIDString)"
                    )
                }
            }
        }
    }

    private func chip(for id: String) -> some View {
        let title = chipMetas[id]?.title
        let label = (title?.isEmpty == false) ? (title ?? id) : id
        return HStack(spacing: LociSpacing.stack(.xs)) {
            Text(label)
                .font(LociTypography.font(.callout))
                .foregroundStyle(LociColors.ink)
            Button {
                remove(id)
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(LociTypography.font(.caption))
                    .foregroundStyle(LociColors.inkSoft)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Remove \(label)")
        }
        .padding(.horizontal, LociSpacing.stack(.sm))
        .padding(.vertical, LociSpacing.stack(.xs))
        .background(LociColors.accentSoft)
        .clipShape(Capsule())
        .accessibilityIdentifier("object-select-chip-\(id)")
    }

    private var selectedSet: Set<String> {
        Set(selectedIDs.map { $0.lowercased() })
    }

    private var visibleCandidates: [LociObjectMeta] {
        candidates.filter { item in
            !selectedSet.contains(item.id.frontMatterIDString.lowercased())
        }
    }

    private var queryTaskID: String {
        "\(query)|\(excluding?.frontMatterIDString ?? "")"
    }

    private func add(_ item: LociObjectMeta) {
        let id = item.id.frontMatterIDString
        guard !selectedSet.contains(id.lowercased()) else { return }
        selectedIDs.append(id)
        chipMetas[id] = item
        onChange()
    }

    private func remove(_ id: String) {
        selectedIDs.removeAll { $0.lowercased() == id.lowercased() }
        chipMetas.removeValue(forKey: id)
        onChange()
    }

    private func reloadCandidates() async {
        let snapshot = query
        if !snapshot.isEmpty {
            try? await Task.sleep(nanoseconds: 180_000_000)
            guard snapshot == query else { return }
        }
        isLoading = true
        defer { isLoading = false }
        do {
            let store = ObjectSelectStore(services: services)
            candidates = try await store.candidates(
                matching: query,
                excluding: excluding,
                limit: 12
            )
            errorMessage = nil
        } catch {
            candidates = []
            errorMessage = error.localizedDescription
        }
    }

    private func reloadChips() async {
        do {
            let store = ObjectSelectStore(services: services)
            chipMetas = try await store.metas(for: selectedIDs)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

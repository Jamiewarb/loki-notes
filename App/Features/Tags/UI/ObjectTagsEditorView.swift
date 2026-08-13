import SwiftUI
import LociCore
import LociDesignSystem

/// Inspector: edit object-level tags in YAML frontmatter (PR17).
struct ObjectTagsEditorView: View {
    var services: AppServices
    let objectID: ObjectID

    @State private var draft: String = ""
    @State private var tags: [String] = []
    @State private var errorMessage: String?
    @State private var isBusy = false
    @State private var saveGeneration: UInt64 = 0

    var body: some View {
        VStack(alignment: .leading, spacing: LociSpacing.stack(.md)) {
            Text("Tags")
                .font(LociTypography.font(.overline))
                .tracking(0.08)
                .foregroundStyle(LociColors.inkSoft)

            Text("Object-level tags in frontmatter. Body #tags are indexed too.")
                .font(LociTypography.font(.caption))
                .foregroundStyle(LociColors.inkSoft)

            if tags.isEmpty {
                Text("No object tags yet.")
                    .font(LociTypography.font(.callout))
                    .foregroundStyle(LociColors.inkSoft)
            } else {
                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 72), spacing: 8, alignment: .leading)],
                    alignment: .leading,
                    spacing: 8
                ) {
                    ForEach(tags, id: \.self) { tag in
                        HStack(spacing: 4) {
                            Button {
                                Task { await services.openTag(tag) }
                            } label: {
                                Text(TagNormalization.display(tag))
                                    .font(LociTypography.font(.caption))
                                    .foregroundStyle(LociColors.accent)
                            }
                            .buttonStyle(.plain)
                            Button {
                                remove(tag)
                            } label: {
                                Image(systemName: "xmark")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundStyle(LociColors.inkSoft)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Remove \(tag)")
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(LociColors.panel)
                        .clipShape(
                            RoundedRectangle(cornerRadius: CGFloat(LociRadius.md), style: .continuous)
                        )
                    }
                }
            }

            HStack(spacing: LociSpacing.stack(.sm)) {
                TextField("Add tag", text: $draft)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { addFromDraft() }
                LociButton("Add", style: .secondary) { addFromDraft() }
                    .disabled(isBusy || TagNormalization.normalize(draft).isEmpty)
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(LociTypography.font(.caption))
                    .foregroundStyle(LociColors.danger)
            }
        }
        .padding(LociSpacing.stack(.lg))
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(LociColors.panel.opacity(0.55))
        .lociAppear(.panel)
        .task(id: objectID.uuidString) { await reload() }
        .accessibilityIdentifier("object-tags-editor")
    }

    private func addFromDraft() {
        let n = TagNormalization.normalize(draft)
        guard !n.isEmpty else { return }
        if !tags.contains(n) {
            tags.append(n)
            scheduleSave()
        }
        draft = ""
    }

    private func remove(_ tag: String) {
        tags.removeAll { $0 == TagNormalization.normalize(tag) }
        scheduleSave()
    }

    private func reload() async {
        isBusy = true
        defer { isBusy = false }
        do {
            if let session = services.activeEditorSession, session.objectID == objectID {
                tags = TagNormalization.uniquing(session.currentTags)
            } else {
                let objects = try await services.ensureObjectService()
                let opened = try await objects.open(id: objectID)
                tags = TagNormalization.uniquing(opened.meta.tags)
            }
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func scheduleSave() {
        saveGeneration &+= 1
        let generation = saveGeneration
        let snapshot = tags
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 350_000_000)
            guard generation == saveGeneration else { return }
            await persist(snapshot)
        }
    }

    private func persist(_ nextTags: [String]) async {
        isBusy = true
        defer { isBusy = false }
        do {
            if let session = services.activeEditorSession, session.objectID == objectID {
                session.applyTags(nextTags)
            } else {
                let objects = try await services.ensureObjectService()
                let opened = try await objects.open(id: objectID)
                var meta = opened.meta
                meta.tags = TagNormalization.uniquing(nextTags)
                try await objects.save(meta: meta, bodyMarkdown: opened.bodyMarkdown)
            }
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

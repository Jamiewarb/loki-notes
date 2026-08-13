#if canImport(SwiftUI)
import SwiftUI
import LociCore
import LociDesignSystem
import LociMarkdown

/// BlockAST editor UI — rich blocks (PR29) + slash / link / tag pickers + turn-into-object.
struct BlockEditorView: View {
    @Bindable var session: EditorSessionBridge
    var services: AppServices?

    @State private var objectTypes: [ObjectType] = []

    var body: some View {
        VStack(alignment: .leading, spacing: LociSpacing.stack(.sm)) {
            ForEach(Array(session.blocks.enumerated()), id: \.offset) { index, block in
                VStack(alignment: .leading, spacing: 4) {
                    Group {
                        if case .queryEmbed(let queryID) = block, let services {
                            QueryEmbedBlockRow(
                                services: services,
                                queryID: queryID,
                                index: index,
                                onFocus: { session.focusedBlockIndex = index },
                                onChangeSlug: { session.setPlainText(at: index, text: $0) }
                            )
                        } else {
                            BlockRowView(
                                index: index,
                                block: block,
                                text: session.plainText(at: index),
                                objectTypes: objectTypes,
                                onFocus: { session.focusedBlockIndex = index },
                                onChange: { session.setPlainText(at: index, text: $0) },
                                onEnter: { before, after in
                                    session.applyEdit(
                                        .splitBlock(blockIndex: index, before: before, after: after)
                                    )
                                    session.focusedBlockIndex = index + 1
                                },
                                onConvert: { kind in
                                    session.focusedBlockIndex = index
                                    session.applyEdit(.convertBlock(blockIndex: index, to: kind))
                                },
                                onToggleTask: {
                                    session.applyEdit(.toggleTask(blockIndex: index, itemIndex: 0))
                                },
                                onTurnInto: { typeID in
                                    session.focusedBlockIndex = index
                                    Task { _ = await session.turnFocusedBlockIntoObject(typeID: typeID) }
                                }
                            )
                        }
                    }
                    .id("\(session.editEpoch)-\(index)")

                    if let styles = session.wikiLinkStylesByBlock[index], !styles.isEmpty {
                        WikiLinkStatusView(styles: styles)
                    }
                }
            }

            if let query = session.slashQuery {
                SlashMenuView(
                    query: query,
                    onSelect: { kind in
                        session.applySlash(kind: kind)
                    }
                )
                .transition(.opacity.combined(with: .move(edge: .top)))
            }

            if let trigger = session.linkTrigger, let services {
                LinksFeature.picker(
                    services: services,
                    query: trigger.query,
                    excluding: session.objectID,
                    onSelect: { meta in
                        session.insertWikiLink(to: meta)
                    }
                )
                .transition(.opacity.combined(with: .move(edge: .top)))
            } else if let trigger = session.tagTrigger, let services {
                TagsFeature.completer(
                    services: services,
                    query: trigger.query,
                    onSelect: { summary in
                        session.insertTag(summary)
                    }
                )
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(.easeOut(duration: 0.18), value: session.slashQuery)
        .animation(.easeOut(duration: 0.18), value: session.linkTrigger?.query)
        .animation(.easeOut(duration: 0.18), value: session.tagTrigger?.query)
        .animation(.easeOut(duration: 0.2), value: session.editEpoch)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .task(id: session.editEpoch) {
            await session.refreshWikiLinkStyles(using: services)
        }
        .task {
            guard let services else { return }
            objectTypes = (try? await services.schema.allTypes()) ?? []
        }
        .accessibilityIdentifier("block-editor")
        .modifier(BlockEditorKeymapModifier(session: session))
    }
}

private struct BlockRowView: View {
    let index: Int
    let block: BlockNode
    let text: String
    let objectTypes: [ObjectType]
    let onFocus: () -> Void
    let onChange: (String) -> Void
    let onEnter: (_ before: String, _ after: String) -> Void
    let onConvert: (SlashBlockKind) -> Void
    let onToggleTask: () -> Void
    let onTurnInto: (ObjectTypeID) -> Void

    @State private var draft: String = ""

    var body: some View {
        HStack(alignment: .top, spacing: LociSpacing.stack(.sm)) {
            leadingChrome
            TextField(placeholder, text: $draft, axis: .vertical)
                .font(rowFont)
                .foregroundStyle(LociColors.ink)
                .textFieldStyle(.plain)
                .lineLimit(1...20)
                .onAppear { draft = text }
                .onChange(of: text) { _, newValue in
                    if draft != newValue { draft = newValue }
                }
                .onChange(of: draft) { _, newValue in
                    onFocus()
                    if newValue != text {
                        onChange(newValue)
                    }
                }
                .onSubmit {
                    onEnter(draft, "")
                }
        }
        .padding(.vertical, 4)
        .contextMenu {
            ForEach(SlashBlockKind.allCases, id: \.self) { kind in
                Button(kind.title) {
                    onConvert(kind)
                }
            }
            if !turnIntoCandidates.isEmpty {
                Divider()
                Menu("Turn into…") {
                    ForEach(turnIntoCandidates, id: \.id.rawValue) { type in
                        Button("\(type.icon) \(type.name)") {
                            onTurnInto(type.id)
                        }
                    }
                }
            }
        }
    }

    private var turnIntoCandidates: [ObjectType] {
        objectTypes.filter { $0.id != .daily && $0.id != .image }
    }

    @ViewBuilder
    private var leadingChrome: some View {
        switch block {
        case .bulletList(let items) where items.first?.isTask == true:
            Button(action: onToggleTask) {
                Image(systemName: items.first?.checked == true ? "checkmark.square" : "square")
                    .foregroundStyle(LociColors.accent)
            }
            .buttonStyle(.plain)
            .frame(width: 22)
        case .bulletList:
            Text("•")
                .foregroundStyle(LociColors.inkSoft)
                .frame(width: 22, alignment: .center)
        case .numberedList(let start, _):
            Text("\(start).")
                .foregroundStyle(LociColors.inkSoft)
                .frame(width: 22, alignment: .trailing)
        case .blockQuote:
            Rectangle()
                .fill(LociColors.accent)
                .frame(width: 3)
                .padding(.trailing, 4)
        case .codeBlock(let language, _) where language?.lowercased() == "mermaid":
            Text("◇")
                .font(LociTypography.font(.caption))
                .foregroundStyle(LociColors.accent)
                .frame(width: 28)
        case .codeBlock:
            Text("{ }")
                .font(LociTypography.font(.caption))
                .foregroundStyle(LociColors.inkSoft)
                .frame(width: 28)
        case .table:
            Text("▦")
                .font(LociTypography.font(.caption))
                .foregroundStyle(LociColors.accent)
                .frame(width: 28)
        case .toggle:
            Image(systemName: "chevron.right.circle")
                .foregroundStyle(LociColors.accent)
                .frame(width: 28)
        case .callout(let kind, _, _):
            Text(String(kind.rawValue.prefix(1)).uppercased())
                .font(LociTypography.font(.caption))
                .foregroundStyle(LociColors.accent)
                .frame(width: 28)
        case .image:
            Image(systemName: "photo")
                .foregroundStyle(LociColors.accent)
                .frame(width: 28)
        case .queryEmbed:
            Text("/q")
                .font(LociTypography.font(.caption))
                .foregroundStyle(LociColors.accent)
                .frame(width: 28)
        case .heading(let level, _):
            Text("H\(level)")
                .font(LociTypography.font(.caption))
                .foregroundStyle(LociColors.accent)
                .frame(width: 28, alignment: .leading)
        default:
            Color.clear.frame(width: 8)
        }
    }

    private var placeholder: String {
        switch block {
        case .heading: return "Heading"
        case .codeBlock(let lang, _) where lang?.lowercased() == "mermaid":
            return "Mermaid diagram"
        case .codeBlock: return "Code"
        case .queryEmbed: return "query-slug"
        case .image: return "Image alt"
        case .blockQuote: return "Quote"
        case .table: return "Table header"
        case .toggle: return "Toggle title"
        case .callout: return "Callout title"
        case .bulletList(let items) where items.first?.isTask == true: return "Task"
        case .bulletList, .numberedList: return "List item"
        default: return "Type / for blocks · @ or [[ to link · # for tags"
        }
    }

    private var rowFont: Font {
        switch block {
        case .heading(let level, _):
            switch level {
            case 1: return LociTypography.font(.display)
            case 2: return LociTypography.font(.title)
            default: return LociTypography.font(.headline)
            }
        case .codeBlock, .queryEmbed, .table:
            return .system(.body, design: .monospaced)
        default:
            return LociTypography.font(.body)
        }
    }
}

/// Query embed row: editable slug + live results panel (PR23).
private struct QueryEmbedBlockRow: View {
    var services: AppServices
    let queryID: String
    let index: Int
    let onFocus: () -> Void
    let onChangeSlug: (String) -> Void

    @State private var draft: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: LociSpacing.stack(.sm)) {
            HStack(alignment: .center, spacing: LociSpacing.stack(.sm)) {
                Text("/query")
                    .font(LociTypography.font(.caption))
                    .foregroundStyle(LociColors.accent)
                    .frame(width: 48, alignment: .leading)
                TextField("query-slug", text: $draft)
                    .font(.system(.body, design: .monospaced))
                    .textFieldStyle(.plain)
                    .onAppear { draft = queryID }
                    .onChange(of: queryID) { _, newValue in
                        if draft != newValue { draft = newValue }
                    }
                    .onChange(of: draft) { _, newValue in
                        onFocus()
                        if newValue != queryID {
                            onChangeSlug(newValue)
                        }
                    }
            }
            QueriesFeature.embed(
                services: services,
                queryID: queryID,
                onOpen: { id in await services.open(objectID: id) }
            )
        }
        .padding(.vertical, 4)
    }
}
#endif

import SwiftUI
import LociCore
import LociDesignSystem

/// Quick capture UI — append to today or enqueue typed create (PR26).
///
/// On Apple, Share / Widget / menu bar call the same `CaptureServing` path;
/// this view is the in-app / DevHarness-facing surface.
struct CaptureQuickAddView: View {
    var services: AppServices
    @State private var draft = ""
    @State private var status = "Ready — append to today or drain inbox."
    @State private var pending: [String] = []
    @State private var lastPath: String?

    private var store: CaptureStore {
        CaptureStore(capture: services.capture)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: LociSpacing.stack(.lg)) {
            HStack(spacing: LociSpacing.stack(.md)) {
                LociIcon(Route.capture.systemImage, size: 22)
                    .foregroundStyle(LociColors.accent)
                Text(Route.capture.title)
                    .font(LociTypography.font(.headline))
                    .foregroundStyle(LociColors.ink)
            }

            Text(
                "Extensions write `.loci/inbox/*.json`. Main app drains → `daily/YYYY-MM-DD.md` or a typed object. Index updates on foreground only."
            )
            .font(LociTypography.font(.callout))
            .foregroundStyle(LociColors.inkSoft)
            .fixedSize(horizontal: false, vertical: true)

            LociTextField("Quick add", text: $draft, placeholder: "Capture a line…")

            HStack(spacing: LociSpacing.stack(.md)) {
                LociButton("Append to today", style: .primary) {
                    Task { await appendDirect() }
                }
                LociButton("Enqueue (extension)", style: .secondary) {
                    Task { await enqueue() }
                }
                LociButton("Drain inbox", style: .secondary) {
                    Task { await drain() }
                }
            }

            if let lastPath {
                Text("Last path: \(lastPath)")
                    .font(LociTypography.font(.caption))
                    .foregroundStyle(LociColors.inkSoft)
            }

            Text(status)
                .font(LociTypography.font(.callout))
                .foregroundStyle(LociColors.ink)

            if !pending.isEmpty {
                VStack(alignment: .leading, spacing: LociSpacing.stack(.sm)) {
                    Text("Pending inbox")
                        .font(LociTypography.font(.overline))
                        .foregroundStyle(LociColors.inkSoft)
                    ForEach(pending, id: \.self) { path in
                        Text(path)
                            .font(LociTypography.font(.caption))
                            .foregroundStyle(LociColors.ink)
                    }
                }
            }

            Spacer(minLength: 0)
        }
        .padding(LociSpacing.stack(.lg))
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .task { await refreshPending() }
    }

    private func appendDirect() async {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            status = "Enter text to append."
            return
        }
        do {
            _ = try await services.ensureCaptureService()
            let result = try await store.quickAdd(text)
            lastPath = result?.relativePath
            draft = ""
            status = "Appended to \(result?.relativePath ?? "today")."
            await refreshPending()
            if let id = result?.objectID {
                await services.open(objectID: id)
            }
        } catch {
            status = "Append failed: \(error.localizedDescription)"
        }
    }

    private func enqueue() async {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            status = "Enter text to enqueue."
            return
        }
        do {
            _ = try await services.ensureCaptureService()
            let path = try await store.enqueueAppend(text, source: .harness)
            lastPath = path
            draft = ""
            status = "Enqueued \(path ?? "inbox item"). Drain on foreground."
            await refreshPending()
        } catch {
            status = "Enqueue failed: \(error.localizedDescription)"
        }
    }

    private func drain() async {
        do {
            _ = try await services.ensureCaptureService()
            let results = try await store.drain()
            status = "Drained \(results.count) item(s)."
            lastPath = results.last?.relativePath
            await refreshPending()
        } catch {
            status = "Drain failed: \(error.localizedDescription)"
        }
    }

    private func refreshPending() async {
        do {
            _ = try? await services.ensureCaptureService()
            pending = try await store.pendingPaths()
        } catch {
            pending = []
        }
    }
}

struct CaptureInspectorView: View {
    var services: AppServices

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: LociSpacing.stack(.md)) {
                Text("Capture surfaces")
                    .font(LociTypography.font(.overline))
                    .tracking(0.08)
                    .foregroundStyle(LociColors.inkSoft)
                Text(
                    "Share extracts text/URL → `.loci/inbox/`. Widget Open today is `loci://daily/today`. Daily remains the inbox."
                )
                .font(LociTypography.font(.callout))
                .foregroundStyle(LociColors.inkSoft)
                LociDivider()
                Text("No feature→feature imports — CaptureServing + DailyNoteServing + ObjectServing.")
                    .font(LociTypography.font(.caption))
                    .foregroundStyle(LociColors.inkSoft)
            }
            .padding(LociSpacing.stack(.lg))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(LociColors.panel.opacity(0.55))
        .lociAppear(.panel)
    }
}

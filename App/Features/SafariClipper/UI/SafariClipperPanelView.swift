import SwiftUI
import LociCore
import LociDesignSystem

/// Safari clipper UI — page URL / title / selection → today or Weblink (PR32).
///
/// On Apple, the Safari App Extension calls the same inbox path; this view is the
/// in-app / DevHarness-facing surface. Features talk protocols only.
struct SafariClipperPanelView: View {
    var services: AppServices
    @State private var pageURL = "https://example.com/article"
    @State private var pageTitle = "Example Article"
    @State private var selection = "A clipped paragraph from the page."
    @State private var status = "Ready — clip to today, save Weblink, or drain inbox."
    @State private var pending: [String] = []
    @State private var lastPath: String?

    private var store: SafariClipperStore {
        SafariClipperStore(safari: services.safariClipper, capture: services.capture)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: LociSpacing.stack(.lg)) {
            HStack(spacing: LociSpacing.stack(.md)) {
                LociIcon(Route.safari.systemImage, size: 22)
                    .foregroundStyle(LociColors.accent)
                Text(Route.safari.title)
                    .font(LociTypography.font(.headline))
                    .foregroundStyle(LociColors.ink)
            }

            Text(
                "Safari extension writes `.loci/inbox/*.json`. Main app drains → `daily/YYYY-MM-DD.md` or `objects/weblink/`. Index updates on foreground only."
            )
            .font(LociTypography.font(.callout))
            .foregroundStyle(LociColors.inkSoft)
            .fixedSize(horizontal: false, vertical: true)

            LociTextField("Page URL", text: $pageURL, placeholder: "https://…")
            LociTextField("Page title", text: $pageTitle, placeholder: "Title")
            LociTextField("Selection", text: $selection, placeholder: "Selected text…")

            HStack(spacing: LociSpacing.stack(.md)) {
                LociButton("Clip to today", style: .primary) {
                    Task { await clipToday() }
                }
                LociButton("Save Weblink", style: .secondary) {
                    Task { await saveWeblink() }
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

    private func makeClip(destination: SafariClipDestination) -> SafariClip {
        SafariClip(
            pageURL: pageURL,
            pageTitle: pageTitle.isEmpty ? nil : pageTitle,
            selection: selection,
            destination: destination
        )
    }

    private func clipToday() async {
        do {
            _ = try await services.ensureSafariClipperService()
            let result = try await store.clip(makeClip(destination: .appendToToday))
            lastPath = result?.relativePath
            status = "Clipped to \(result?.relativePath ?? "today")."
            await refreshPending()
            if let id = result?.objectID {
                await services.open(objectID: id)
            }
        } catch {
            status = "Clip failed: \(error.localizedDescription)"
        }
    }

    private func saveWeblink() async {
        do {
            _ = try await services.ensureSafariClipperService()
            let result = try await store.clip(makeClip(destination: .weblinkObject))
            lastPath = result?.relativePath
            status = "Saved Weblink \(result?.relativePath ?? "")."
            await refreshPending()
            if let id = result?.objectID {
                await services.prefetchWeblinkPreview(objectID: id)
                await services.open(objectID: id)
            }
        } catch {
            status = "Weblink failed: \(error.localizedDescription)"
        }
    }

    private func drain() async {
        do {
            _ = try await services.ensureSafariClipperService()
            let results = try await store.drain()
            status = "Drained \(results.count) item(s)."
            lastPath = results.last?.relativePath
            for result in results {
                await services.prefetchWeblinkPreview(objectID: result.objectID)
            }
            await refreshPending()
        } catch {
            status = "Drain failed: \(error.localizedDescription)"
        }
    }

    private func refreshPending() async {
        do {
            _ = try? await services.ensureSafariClipperService()
            pending = try await store.pendingPaths()
        } catch {
            pending = []
        }
    }
}

struct SafariClipperInspectorView: View {
    var services: AppServices

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: LociSpacing.stack(.md)) {
                Text("Safari clipper")
                    .font(LociTypography.font(.overline))
                    .tracking(0.08)
                    .foregroundStyle(LociColors.inkSoft)
                Text(
                    "Extension enqueues Capture inbox JSON. Drain → today line (`· safari`) or Weblink with `url` property. Index never from the extension."
                )
                .font(LociTypography.font(.callout))
                .foregroundStyle(LociColors.inkSoft)
                LociDivider()
                Text("SafariClipServing + CaptureServing + ObjectServing — no feature→feature imports.")
                    .font(LociTypography.font(.caption))
                    .foregroundStyle(LociColors.inkSoft)
                Text("Vault: \(services.spaceName)")
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

struct SafariClipperSettingsNote: View {
    var services: AppServices

    var body: some View {
        VStack(alignment: .leading, spacing: LociSpacing.stack(.sm)) {
            Text("Safari clipper")
                .font(LociTypography.font(.overline))
                .foregroundStyle(LociColors.inkSoft)
            Text(
                "Enable the Loci Safari extension to clip selection/page into today’s daily or a Weblink object. Staging uses `.loci/inbox/` (same as Share)."
            )
            .font(LociTypography.font(.callout))
            .foregroundStyle(LociColors.inkSoft)
            Text(services.safariClipper == nil ? "Wire after vault open." : "Ready.")
                .font(LociTypography.font(.caption))
                .foregroundStyle(LociColors.inkSoft)
        }
    }
}

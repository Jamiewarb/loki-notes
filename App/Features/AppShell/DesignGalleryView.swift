import SwiftUI
import LociDesignSystem

/// Visual catalog of design tokens and primitives (Apple platforms).
/// DevHarness mirrors the same tokens for Linux agents.
struct DesignGalleryView: View {
    @State private var sampleText = "A page about gardens"
    @State private var selectedRow = "daily"
    @State private var showEmpty = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: LociSpacing.stack(.xxl)) {
                brandHeader
                colorSection
                typeSection
                spacingSection
                componentSection
                motionSection
            }
            .padding(LociSpacing.stack(.xl))
            .frame(maxWidth: 720, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .background { LociAtmosphereBackground() }
    }

    private var brandHeader: some View {
        VStack(alignment: .leading, spacing: LociSpacing.stack(.sm)) {
            Text(LociDesignSystem.brandName)
                .font(LociTypography.font(.brand))
                .tracking(LociTypography.brandTracking * LociTypography.brandSize)
                .foregroundStyle(LociColors.ink)
                .lociAppear(.brand)
            Text(LociDesignSystem.tagline)
                .font(LociTypography.font(.body))
                .foregroundStyle(LociColors.inkSoft)
                .lociAppear(.soft)
            Text("Design gallery · \(LociDesignSystem.visualDirection) · \(LociDesignSystem.version)")
                .font(LociTypography.font(.caption))
                .foregroundStyle(LociColors.inkSoft)
        }
    }

    private var colorSection: some View {
        gallerySection(title: "Colors", caption: "Sage paper, forest ink, moss-teal accent.") {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), spacing: 12)], spacing: 12) {
                swatch("Ink", LociColors.ink, LociColors.inkHex)
                swatch("Ink soft", LociColors.inkSoft, LociColors.inkSoftHex)
                swatch("Paper", LociColors.paper, LociColors.paperHex)
                swatch("Paper deep", LociColors.paperDeep, LociColors.paperDeepHex)
                swatch("Accent", LociColors.accent, LociColors.accentHex)
                swatch("Accent soft", LociColors.accentSoft, LociColors.accentSoftHex)
                swatch("Mist", LociColors.mist, LociColors.mistHex)
                swatch("Danger", LociColors.danger, LociColors.dangerHex)
            }
        }
    }

    private var typeSection: some View {
        gallerySection(title: "Typography", caption: "Fraunces display · Source Sans 3 body.") {
            VStack(alignment: .leading, spacing: LociSpacing.stack(.md)) {
                ForEach(LociTypography.Role.allCases, id: \.self) { role in
                    Text("\(role.rawValue) · \(Int(LociTypography.size(for: role)))pt")
                        .font(LociTypography.font(role))
                        .foregroundStyle(LociColors.ink)
                }
            }
        }
    }

    private var spacingSection: some View {
        gallerySection(title: "Spacing", caption: "xxs→xxxl scale for stack rhythm.") {
            VStack(alignment: .leading, spacing: LociSpacing.stack(.sm)) {
                ForEach(LociSpacing.Token.allCases, id: \.self) { token in
                    HStack(spacing: LociSpacing.stack(.md)) {
                        Text(token.rawValue)
                            .font(LociTypography.font(.caption))
                            .frame(width: 48, alignment: .leading)
                        RoundedRectangle(cornerRadius: 2)
                            .fill(LociColors.accent)
                            .frame(width: CGFloat(token.value) * 4, height: 10)
                        Text("\(Int(token.value))")
                            .font(LociTypography.font(.caption))
                            .foregroundStyle(LociColors.inkSoft)
                    }
                }
            }
        }
    }

    private var componentSection: some View {
        gallerySection(title: "Components", caption: "Buttons, fields, rows, empty state, divider.") {
            VStack(alignment: .leading, spacing: LociSpacing.stack(.lg)) {
                HStack(spacing: LociSpacing.stack(.md)) {
                    LociButton("Primary", style: .primary) {}
                    LociButton("Secondary", style: .secondary) {}
                }
                HStack(spacing: LociSpacing.stack(.md)) {
                    LociButton("Quiet", style: .quiet, systemImage: "plus") {}
                    LociButton("Delete", style: .destructive) {}
                }

                LociTextField("Title", text: $sampleText, placeholder: "Untitled")

                VStack(spacing: LociSpacing.stack(.xs)) {
                    LociListRow(
                        title: "Daily",
                        subtitle: "Today’s note",
                        systemImage: "sun.max",
                        isSelected: selectedRow == "daily"
                    ) { selectedRow = "daily" }
                    LociListRow(
                        title: "Search",
                        subtitle: "Full-text index",
                        systemImage: "magnifyingglass",
                        isSelected: selectedRow == "search"
                    ) { selectedRow = "search" }
                }

                LociDivider()

                Toggle("Show empty state", isOn: $showEmpty)
                    .font(LociTypography.font(.callout))
                    .tint(LociColors.accent)

                if showEmpty {
                    LociEmptyState(
                        title: "No pages yet",
                        message: "Create a Page object — vault files are source of truth.",
                        systemImage: "doc.badge.plus",
                        actionTitle: "New Page"
                    ) {}
                    .lociPanelTransition()
                }
            }
        }
    }

    private var motionSection: some View {
        gallerySection(title: "Motion", caption: "Brand rise, soft appear, panel transition.") {
            Text(
                "Durations — brand \(LociMotion.brandDuration)s, shell \(LociMotion.shellDuration)s, panel \(LociMotion.panelDuration)s."
            )
            .font(LociTypography.font(.callout))
            .foregroundStyle(LociColors.inkSoft)
        }
    }

    private func gallerySection<Content: View>(
        title: String,
        caption: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: LociSpacing.stack(.md)) {
            Text(title)
                .font(LociTypography.font(.display))
                .foregroundStyle(LociColors.ink)
            Text(caption)
                .font(LociTypography.font(.callout))
                .foregroundStyle(LociColors.inkSoft)
            content()
        }
        .lociAppear(.panel)
    }

    private func swatch(_ name: String, _ color: Color, _ hex: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            RoundedRectangle(cornerRadius: LociRadius.control, style: .continuous)
                .fill(color)
                .frame(height: 56)
                .overlay(
                    RoundedRectangle(cornerRadius: LociRadius.control, style: .continuous)
                        .strokeBorder(LociColors.line, lineWidth: 1)
                )
            Text(name)
                .font(LociTypography.font(.caption))
                .foregroundStyle(LociColors.ink)
            Text(hex)
                .font(LociTypography.font(.overline))
                .foregroundStyle(LociColors.inkSoft)
        }
    }
}

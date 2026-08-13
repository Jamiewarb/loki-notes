import XCTest
@testable import LociDesignSystem

final class DesignTokenTests: XCTestCase {
    func testBrandIdentity() {
        XCTAssertEqual(LociDesignSystem.brandName, "Loci")
        XCTAssertEqual(LociDesignSystem.visualDirection, "editorial-sage")
        XCTAssertTrue(LociDesignSystem.version.contains("pr02"))
    }

    func testSpacingScaleIsAscending() {
        let scale = LociSpacing.scale
        XCTAssertEqual(scale, [2, 4, 8, 12, 16, 24, 32, 48])
        for i in 1..<scale.count {
            XCTAssertLessThan(scale[i - 1], scale[i])
        }
        XCTAssertEqual(LociSpacing.Token.allCases.map(\.value), scale)
    }

    func testColorHexConstants() {
        XCTAssertEqual(LociColors.inkHex, "#1A2421")
        XCTAssertEqual(LociColors.paperHex, "#E8EFE8")
        XCTAssertEqual(LociColors.accentHex, "#0F6B5C")
        XCTAssertEqual(LociColors.accentSoftHex, "#C5E4DC")
        XCTAssertEqual(LociColors.dangerHex, "#9B3A2F")
        XCTAssertEqual(LociColors.paletteHexes.count, 10)
        for hex in LociColors.paletteHexes {
            XCTAssertTrue(hex.hasPrefix("#"), "expected # prefix: \(hex)")
            XCTAssertEqual(hex.count, 7, "expected #RRGGBB: \(hex)")
        }
    }

    func testAccentRGBInMossRange() {
        let accent = LociColors.accentRGB
        // Moss-teal: green dominant over red/blue, not purple-leaning.
        XCTAssertGreaterThan(accent.g, accent.r)
        XCTAssertGreaterThan(accent.g, accent.b)
        XCTAssertLessThan(accent.r, 0.2)
    }

    func testTypographyFamiliesAndSizes() {
        XCTAssertEqual(LociTypography.displayFamily, "Fraunces")
        XCTAssertEqual(LociTypography.bodyFamily, "Source Sans 3")
        XCTAssertEqual(LociTypography.size(for: .brand), 44)
        XCTAssertEqual(LociTypography.size(for: .body), 16)
        XCTAssertTrue(LociTypography.isDisplayRole(.brand))
        XCTAssertFalse(LociTypography.isDisplayRole(.body))
    }

    func testDynamicTypeTextStyleMapping() {
        XCTAssertTrue(LociTypography.usesDynamicTypeRelativeTo)
        XCTAssertEqual(LociTypography.dynamicTypeTextStyleName(for: .brand), "largeTitle")
        XCTAssertEqual(LociTypography.dynamicTypeTextStyleName(for: .display), "title")
        XCTAssertEqual(LociTypography.dynamicTypeTextStyleName(for: .title), "title2")
        XCTAssertEqual(LociTypography.dynamicTypeTextStyleName(for: .headline), "headline")
        XCTAssertEqual(LociTypography.dynamicTypeTextStyleName(for: .body), "body")
        XCTAssertEqual(LociTypography.dynamicTypeTextStyleName(for: .callout), "callout")
        XCTAssertEqual(LociTypography.dynamicTypeTextStyleName(for: .caption), "caption")
        XCTAssertEqual(LociTypography.dynamicTypeTextStyleName(for: .overline), "caption")
        XCTAssertEqual(LociTypography.size(for: .brand), 44)
        XCTAssertEqual(LociTypography.size(for: .display), 28)
        XCTAssertEqual(LociTypography.size(for: .caption), 12)
    }

    func testRadiusAndElevationTokens() {
        XCTAssertEqual(LociRadius.scale, [0, 6, 10, 14, 20])
        XCTAssertEqual(LociElevation.restOpacity, 0.08, accuracy: 0.0001)
        XCTAssertEqual(LociElevation.raisedBlur, 40)
    }
}

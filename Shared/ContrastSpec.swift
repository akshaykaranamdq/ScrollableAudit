//
//  ContrastSpec.swift
//
//  GROUND TRUTH, shared by the app target (which renders each spec) and the
//  UI-test target (which grades Apple's audit against it). Because both sides
//  read the same spec, the screen and its answer key cannot drift apart.
//
//  Foundation only: no SwiftUI or XCTest, so it compiles into both targets.
//

import Foundation

/// What a correct contrast audit should say about an element.
nonisolated enum ExpectedOutcome: String, Sendable {
    /// Meets WCAG 1.4.3 for its text size: should NOT be flagged.
    case pass
    /// Below the WCAG threshold: SHOULD be flagged.
    case fail
    /// Disabled control. WCAG exempts inactive components, so flagging it is
    /// not a defect, but it is recorded separately so tools can be compared.
    case exempt
    /// Text over a gradient or image: no single correct ratio exists.
    case unmeasurable
}

/// WCAG 2.x relative luminance and contrast ratio.
nonisolated enum ContrastMath {

    static func luminance(_ hex: UInt32) -> Double {
        func channel(_ value: UInt32) -> Double {
            let c = Double(value) / 255.0
            return c <= 0.04045 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * channel((hex >> 16) & 0xFF)
            + 0.7152 * channel((hex >> 8) & 0xFF)
            + 0.0722 * channel(hex & 0xFF)
    }

    static func ratio(_ a: UInt32, _ b: UInt32) -> Double {
        let la = luminance(a), lb = luminance(b)
        return (max(la, lb) + 0.05) / (min(la, lb) + 0.05)
    }
}

/// One audited piece of text: how it is drawn, and what the audit should say.
nonisolated struct ContrastSpec: Identifiable, Hashable, Sendable {
    /// accessibilityIdentifier of the element, e.g. "SHOP-P2-PRICE".
    let id: String
    let screen: String
    let text: String
    let foreground: UInt32
    let background: UInt32
    let size: Double
    let bold: Bool
    let enabled: Bool
    let measurable: Bool

    init(_ id: String, _ screen: String, _ text: String,
         fg: UInt32, bg: UInt32, size: Double,
         bold: Bool = false, enabled: Bool = true, measurable: Bool = true) {
        self.id = id
        self.screen = screen
        self.text = text
        self.foreground = fg
        self.background = bg
        self.size = size
        self.bold = bold
        self.enabled = enabled
        self.measurable = measurable
    }

    var ratio: Double { ContrastMath.ratio(foreground, background) }

    /// WCAG "large text": 18 pt regular or larger, or 14 pt bold or larger.
    var isLargeText: Bool { size >= 18 || (bold && size >= 14) }

    var threshold: Double { isLargeText ? 3.0 : 4.5 }

    var expected: ExpectedOutcome {
        if !measurable { return .unmeasurable }
        if !enabled { return .exempt }
        return ratio < threshold ? .fail : .pass
    }
}

/// Colours used across the screens. Mostly real design-system colours (the
/// iOS system palette, plus a few brand colours) because those are the ones
/// that quietly fail contrast in production apps.
nonisolated enum Pal {
    static let white: UInt32 = 0xFFFFFF
    static let black: UInt32 = 0x000000
    static let grouped: UInt32 = 0xF2F2F7     // grouped background
    static let ink: UInt32 = 0x1C1C1E         // primary text / dark surface
    static let border: UInt32 = 0xD1D1D6

    static let text2: UInt32 = 0x6C6C70       // secondary text
    static let text3: UInt32 = 0x8A8A8E       // tertiary text
    static let hint: UInt32 = 0x767680        // 4.49:1 on white, just under AA
    static let placeholder: UInt32 = 0xA0A0A5

    static let sysBlue: UInt32 = 0x007AFF
    static let sysRed: UInt32 = 0xFF3B30
    static let sysGreen: UInt32 = 0x34C759
    static let sysOrange: UInt32 = 0xFF9500
    static let sysPurple: UInt32 = 0xAF52DE
    static let sysTeal: UInt32 = 0x30B0C7
    static let sysGray: UInt32 = 0x8E8E93
    static let sysGray2: UInt32 = 0xAEAEB2
    static let sysYellow: UInt32 = 0xFFCC00

    static let darkBlue: UInt32 = 0x0A5BD6
    static let darkGreen: UInt32 = 0x1E7B34
    static let darkRed: UInt32 = 0xC62828

    static let brandCoral: UInt32 = 0xF4645F
    static let brandNavy: UInt32 = 0x1B3A6B
}

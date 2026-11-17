//
//  RuleGroundTruth.swift
//
//  Ground truth for EVERY audit rule, not just contrast.
//
//  Contrast is computed from colours (see ContrastSpec). The other rules come
//  from `ControlSpec`: a control built in a known way (an icon button of a given
//  size, with or without an accessibility label; text with a fixed or scaling
//  font; text that is truncated or wraps; and so on). What a correct audit
//  should say about it follows from how it is built:
//
//      hit region                44 pt minimum target
//      element description       interactive control needs an accessible name
//      dynamic type              text should scale with the user's text size
//      text clipped              text should not be truncated or cut off
//      trait                     tappable text needs the button trait; the
//                                button trait should not sit on a non-control
//      element detection         a visible control must be exposed to
//                                accessibility
//
//  These expectations come from the accessibility guidelines, NOT from what
//  Apple's audit happens to report. Review them: they are the answer key.
//

import Foundation

/// The audit rules, named exactly as A11yScrollAudit names them in
/// `AuditFinding.type`, so a finding's type maps straight to a rule.
nonisolated enum AuditRule: String, CaseIterable, Sendable {
    case contrast
    case elementDetection
    case hitRegion
    case sufficientElementDescription
    case dynamicType
    case textClipped
    case trait

    var title: String {
        switch self {
        case .contrast: "Contrast"
        case .elementDetection: "Element detection"
        case .hitRegion: "Hit region"
        case .sufficientElementDescription: "Element description"
        case .dynamicType: "Dynamic Type"
        case .textClipped: "Text clipped"
        case .trait: "Trait"
        }
    }

    /// False when the offending element is not in the accessibility tree at
    /// all (element detection finds things that are NOT exposed), so a finding
    /// cannot be tied to one element and is graded per screen by count.
    var gradesPerElement: Bool { self != .elementDetection }

    /// Parses a rule selection such as "all", "contrast", or
    /// "contrast, hitRegion". Case-insensitive; "elementDescription" is an
    /// alias for sufficientElementDescription. Unknown names are ignored.
    static func parse(_ list: String) -> [AuditRule] {
        let names = list.split(whereSeparator: { $0 == "," || $0 == " " }).map { $0.lowercased() }
        if names.contains("all") { return allCases }
        var picked = Set<AuditRule>()
        for name in names {
            if name == "elementdescription" { picked.insert(.sufficientElementDescription); continue }
            if let rule = allCases.first(where: { $0.rawValue.lowercased() == name }) { picked.insert(rule) }
        }
        return allCases.filter { picked.contains($0) }
    }
}

/// One thing a correct audit should say: "for this element, under this rule,
/// the outcome is X".
nonisolated struct Expectation: Hashable, Sendable {
    let id: String
    let screen: String
    let rule: AuditRule
    let outcome: ExpectedOutcome
    let detail: String
}

/// A control built in a known way, so every rule's correct answer is known.
nonisolated struct ControlSpec: Identifiable, Hashable, Sendable {

    enum ClipMode: Hashable, Sendable {
        case ellipsis      // single line, truncated with "..."
        case hard          // second line cut off by the frame
    }

    enum Kind: Hashable, Sendable {
        /// Icon-only button: tests hit region AND element description.
        case iconButton(side: Double, labelled: Bool)
        /// Text with a fixed point size: ignores Dynamic Type.
        case fixedFontText(size: Double)
        /// Text using a text style: scales with Dynamic Type.
        case scalingText
        /// Text forced into a width too narrow for it.
        case clippedText(width: Double, mode: ClipMode)
        /// The same text given room to wrap.
        case wrappingText(width: Double)
        /// Tappable text; `buttonTrait` says whether it carries the button trait.
        case tapText(buttonTrait: Bool)
        /// Text carrying the button trait that does nothing when tapped.
        case fakeButton
        /// A visible, tappable control hidden from accessibility.
        case hiddenControl
    }

    let id: String
    let screen: String
    /// Visible text, or the accessibility label for icon buttons.
    let text: String
    let kind: Kind
    /// SF Symbol for icon buttons and hidden controls.
    let symbol: String

    init(_ id: String, _ screen: String, _ text: String, _ kind: Kind, symbol: String = "star.fill") {
        self.id = id
        self.screen = screen
        self.text = text
        self.kind = kind
        self.symbol = symbol
    }

    /// What a correct audit should say about this control, per rule.
    var expectations: [Expectation] {
        func expect(_ rule: AuditRule, _ outcome: ExpectedOutcome, _ why: String) -> Expectation {
            Expectation(id: id, screen: screen, rule: rule, outcome: outcome, detail: why)
        }
        switch kind {
        case .iconButton(let side, let labelled):
            return [
                expect(.hitRegion, side >= 44 ? .pass : .fail, "\(Int(side))pt target (minimum 44pt)"),
                expect(.sufficientElementDescription, labelled ? .pass : .fail,
                       labelled ? "icon button with an accessibility label" : "icon-only button, no accessibility label"),
            ]
        case .fixedFontText(let size):
            return [expect(.dynamicType, .fail, "fixed \(Int(size))pt font ignores Dynamic Type")]
        case .scalingText:
            return [expect(.dynamicType, .pass, "text style scales with Dynamic Type")]
        case .clippedText(let width, let mode):
            return [expect(.textClipped, .fail, mode == .ellipsis
                           ? "single line truncated in \(Int(width))pt"
                           : "text cut off by a \(Int(width))pt frame")]
        case .wrappingText(let width):
            return [expect(.textClipped, .pass, "wraps freely in \(Int(width))pt")]
        case .tapText(let buttonTrait):
            return [expect(.trait, buttonTrait ? .pass : .fail,
                           buttonTrait ? "tappable text with the button trait" : "tappable text without the button trait")]
        case .fakeButton:
            return [expect(.trait, .fail, "button trait on text that does nothing")]
        case .hiddenControl:
            return [expect(.elementDetection, .fail, "visible tappable control hidden from accessibility")]
        }
    }
}

nonisolated enum RuleGroundTruth {

    static func controls(for screen: String) -> [ControlSpec] {
        all.filter { $0.screen == screen }
    }

    static func control(_ id: String) -> ControlSpec {
        guard let control = byID[id] else { fatalError("No control spec with id \(id)") }
        return control
    }

    static let all: [ControlSpec] =
        [shop, shopDetail, dashboard, settings, checkout].flatMap { $0 }

    static let byID: [String: ControlSpec] =
        Dictionary(uniqueKeysWithValues: all.map { ($0.id, $0) })

    // MARK: Shop

    private static let shop: [ControlSpec] = [
        // Favourite buttons on the six product cards: every combination of
        // target size and labelling, including one just under 44pt.
        ControlSpec("SHOP-FAV-1", "shop", "Add Aero Runner Shoes to favourites", .iconButton(side: 44, labelled: true), symbol: "heart.fill"),
        ControlSpec("SHOP-FAV-2", "shop", "Add Trail Jacket to favourites", .iconButton(side: 44, labelled: false), symbol: "heart.fill"),
        ControlSpec("SHOP-FAV-3", "shop", "Add Studio Headphones to favourites", .iconButton(side: 28, labelled: true), symbol: "heart.fill"),
        ControlSpec("SHOP-FAV-4", "shop", "Add Canvas Tote to favourites", .iconButton(side: 28, labelled: false), symbol: "heart.fill"),
        ControlSpec("SHOP-FAV-5", "shop", "Add Ceramic Mug Set to favourites", .iconButton(side: 48, labelled: true), symbol: "heart.fill"),
        ControlSpec("SHOP-FAV-6", "shop", "Add Linen Shirt to favourites", .iconButton(side: 43, labelled: true), symbol: "heart.fill"),
        // Delivery notes.
        ControlSpec("SHOP-DT-FIXED", "shop", "Delivery in 2 to 4 business days", .fixedFontText(size: 15)),
        ControlSpec("SHOP-DT-SCALE", "shop", "Easy 30 day returns", .scalingText),
        // Category chips in a 120pt column.
        ControlSpec("SHOP-TC-ELLIPSIS", "shop", "Running and trail shoes", .clippedText(width: 120, mode: .ellipsis)),
        ControlSpec("SHOP-TC-HARD", "shop", "Waterproof outdoor jackets and shells", .clippedText(width: 120, mode: .hard)),
        ControlSpec("SHOP-TC-WRAP", "shop", "Everyday canvas bags and totes", .wrappingText(width: 120)),
        // Text links.
        ControlSpec("SHOP-TRAIT-SEEALL", "shop", "See all", .tapText(buttonTrait: false)),
        ControlSpec("SHOP-TRAIT-DEALS", "shop", "View deals", .tapText(buttonTrait: true)),
        // A custom gift-card control that never made it into the accessibility tree.
        ControlSpec("SHOP-HIDDEN-GIFT", "shop", "Gift cards", .hiddenControl, symbol: "gift.fill"),
    ]

    // MARK: Product detail

    private static let shopDetail: [ControlSpec] = [
        ControlSpec("DET-ICON-SHARE", "shop-detail", "Share", .iconButton(side: 30, labelled: true), symbol: "square.and.arrow.up"),
        ControlSpec("DET-ICON-FAV", "shop-detail", "Favourite", .iconButton(side: 44, labelled: false), symbol: "heart"),
        ControlSpec("DET-ICON-COMPARE", "shop-detail", "Compare", .iconButton(side: 44, labelled: true), symbol: "arrow.left.arrow.right"),
        ControlSpec("DET-ICON-ZOOM", "shop-detail", "Zoom image", .iconButton(side: 28, labelled: false), symbol: "plus.magnifyingglass"),
        ControlSpec("DET-DT-FIXED", "shop-detail", "Product code AR-2291", .fixedFontText(size: 12)),
        ControlSpec("DET-DT-SCALE", "shop-detail", "Machine washable at 30 degrees", .scalingText),
        ControlSpec("DET-TC-ELLIPSIS", "shop-detail", "Lightweight knit upper with responsive foam midsole", .clippedText(width: 150, mode: .ellipsis)),
        ControlSpec("DET-TRAIT-FAKE", "shop-detail", "Free returns policy", .fakeButton),
        ControlSpec("DET-TRAIT-TAP", "shop-detail", "Size guide", .tapText(buttonTrait: false)),
        ControlSpec("DET-HIDDEN-ZOOM", "shop-detail", "Image zoom", .hiddenControl, symbol: "viewfinder"),
    ]

    // MARK: Dashboard

    private static let dashboard: [ControlSpec] = [
        ControlSpec("DASH-ICON-1", "dashboard", "Refresh", .iconButton(side: 44, labelled: true), symbol: "arrow.clockwise"),
        ControlSpec("DASH-ICON-2", "dashboard", "Filter", .iconButton(side: 32, labelled: true), symbol: "line.3.horizontal.decrease"),
        ControlSpec("DASH-ICON-3", "dashboard", "Export", .iconButton(side: 44, labelled: false), symbol: "square.and.arrow.down"),
        ControlSpec("DASH-ICON-4", "dashboard", "Dashboard settings", .iconButton(side: 30, labelled: false), symbol: "gearshape"),
        ControlSpec("DASH-DT-FIXED", "dashboard", "Updated just now", .fixedFontText(size: 13)),
        ControlSpec("DASH-DT-SCALE", "dashboard", "Data refreshes every 5 minutes", .scalingText),
        ControlSpec("DASH-TC-ELLIPSIS", "dashboard", "Quarterly recurring revenue by region", .clippedText(width: 130, mode: .ellipsis)),
        ControlSpec("DASH-TC-WRAP", "dashboard", "Monthly active customers by plan", .wrappingText(width: 130)),
        ControlSpec("DASH-TRAIT-ALL", "dashboard", "View all activity", .tapText(buttonTrait: false)),
        ControlSpec("DASH-TRAIT-OK", "dashboard", "Open reports", .tapText(buttonTrait: true)),
        ControlSpec("DASH-HIDDEN-FAB", "dashboard", "Add widget", .hiddenControl, symbol: "plus"),
    ]

    // MARK: Settings

    private static let settings: [ControlSpec] = [
        ControlSpec("SET-ICON-HELP", "settings", "Help", .iconButton(side: 44, labelled: true), symbol: "questionmark.circle"),
        ControlSpec("SET-ICON-INFO", "settings", "Info", .iconButton(side: 28, labelled: false), symbol: "info.circle"),
        ControlSpec("SET-DT-FIXED", "settings", "Storage used: 2.4 GB", .fixedFontText(size: 15)),
        ControlSpec("SET-DT-SCALE", "settings", "Storage plan: 5 GB free", .scalingText),
        ControlSpec("SET-TC-ELLIPSIS", "settings", "Email used for account recovery and billing notices", .clippedText(width: 140, mode: .ellipsis)),
        ControlSpec("SET-TC-WRAP", "settings", "Language used for emails and notifications", .wrappingText(width: 140)),
        ControlSpec("SET-TRAIT-PRIVACY", "settings", "Privacy policy", .tapText(buttonTrait: false)),
        ControlSpec("SET-TRAIT-TERMS", "settings", "Terms of use", .tapText(buttonTrait: true)),
        ControlSpec("SET-TRAIT-FAKE", "settings", "Manage subscription", .fakeButton),
    ]

    // MARK: Checkout

    private static let checkout: [ControlSpec] = [
        ControlSpec("CO-ICON-SCAN", "checkout", "Scan card", .iconButton(side: 44, labelled: false), symbol: "camera.fill"),
        ControlSpec("CO-ICON-REMOVE", "checkout", "Remove item", .iconButton(side: 24, labelled: true), symbol: "xmark"),
        ControlSpec("CO-ICON-EDIT", "checkout", "Edit address", .iconButton(side: 44, labelled: true), symbol: "pencil"),
        ControlSpec("CO-DT-FIXED", "checkout", "Estimated delivery: Thursday", .fixedFontText(size: 15)),
        ControlSpec("CO-DT-SCALE", "checkout", "Delivery window: 9am to 1pm", .scalingText),
        ControlSpec("CO-TC-HARD", "checkout", "Leave the parcel with the neighbour if nobody is home", .clippedText(width: 150, mode: .hard)),
        ControlSpec("CO-TC-WRAP", "checkout", "Ring the bell twice and wait at the gate", .wrappingText(width: 150)),
        ControlSpec("CO-TRAIT-CHANGE", "checkout", "Change payment method", .tapText(buttonTrait: false)),
        ControlSpec("CO-HIDDEN-BRANDS", "checkout", "Card brand picker", .hiddenControl, symbol: "creditcard.fill"),
    ]
}

nonisolated extension GroundTruth {

    /// Everything a correct audit should say about one screen, for all rules.
    static func expectations(for screen: String) -> [Expectation] {
        let contrast = specs(for: screen).map { spec in
            Expectation(id: spec.id, screen: screen, rule: .contrast, outcome: spec.expected,
                        detail: String(format: "%.2f:1 vs %.1f (%@ text)", spec.ratio, spec.threshold,
                                       spec.isLargeText ? "large" : "normal"))
        }
        let others = RuleGroundTruth.controls(for: screen).flatMap { $0.expectations }
        return contrast + others
    }

    /// Screens that have ground truth for at least one of the given rules.
    static func screens(covering rules: [AuditRule]) -> [String] {
        screens.filter { screen in
            expectations(for: screen).contains { rules.contains($0.rule) }
        }
    }
}

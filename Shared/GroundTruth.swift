//
//  GroundTruth.swift
//
//  Every audited piece of text on every screen, with its colours, size and
//  expected outcome. Screens render from these specs; tests grade against them.
//
//  Row-like screens (products, KPI cards, feed, settings) are generated from
//  small tables below, so adding a row adds its ground truth automatically.
//

import Foundation

// MARK: - Row models (shared by the views and the registry)

nonisolated struct Product: Identifiable, Hashable, Sendable {
    let n: Int
    let name: String
    let price: String
    let titleFG: UInt32
    let priceFG: UInt32
    let badge: String?
    let badgeFG: UInt32
    let badgeBG: UInt32
    let ctaText: String
    let ctaFG: UInt32
    let ctaBG: UInt32
    let inStock: Bool
    let swatch: UInt32

    var id: Int { n }

    var titleSpec: ContrastSpec {
        ContrastSpec("SHOP-P\(n)-TITLE", "shop", name, fg: titleFG, bg: Pal.white, size: 17)
    }
    var priceSpec: ContrastSpec {
        ContrastSpec("SHOP-P\(n)-PRICE", "shop", price, fg: priceFG, bg: Pal.white, size: 20, bold: true)
    }
    var badgeSpec: ContrastSpec? {
        guard let badge else { return nil }
        return ContrastSpec("SHOP-P\(n)-BADGE", "shop", badge, fg: badgeFG, bg: badgeBG, size: 11, bold: true)
    }
    var ctaSpec: ContrastSpec {
        ContrastSpec("SHOP-P\(n)-CTA", "shop", ctaText, fg: ctaFG, bg: ctaBG, size: 15, enabled: inStock)
    }
    var specs: [ContrastSpec] {
        [titleSpec, priceSpec] + (badgeSpec.map { [$0] } ?? []) + [ctaSpec]
    }
}

nonisolated struct Kpi: Identifiable, Hashable, Sendable {
    let n: Int
    let label: String
    let labelFG: UInt32
    let value: String
    let valueFG: UInt32
    let delta: String
    let deltaFG: UInt32
    let cardBG: UInt32

    var id: Int { n }

    var labelSpec: ContrastSpec { ContrastSpec("DASH-K\(n)-LABEL", "dashboard", label, fg: labelFG, bg: cardBG, size: 13) }
    var valueSpec: ContrastSpec { ContrastSpec("DASH-K\(n)-VALUE", "dashboard", value, fg: valueFG, bg: cardBG, size: 28, bold: true) }
    var deltaSpec: ContrastSpec { ContrastSpec("DASH-K\(n)-DELTA", "dashboard", delta, fg: deltaFG, bg: cardBG, size: 12, bold: true) }
    var specs: [ContrastSpec] { [labelSpec, valueSpec, deltaSpec] }
}

nonisolated struct StatusChip: Identifiable, Hashable, Sendable {
    let n: Int
    let text: String
    let fg: UInt32
    let bg: UInt32

    var id: Int { n }
    var spec: ContrastSpec { ContrastSpec("DASH-C\(n)", "dashboard", text, fg: fg, bg: bg, size: 12, bold: true) }
}

nonisolated struct FeedItem: Identifiable, Hashable, Sendable {
    let n: Int
    let title: String
    let titleFG: UInt32
    let subtitle: String
    let subtitleFG: UInt32
    let time: String
    let timeFG: UInt32

    var id: Int { n }

    var titleSpec: ContrastSpec { ContrastSpec("DASH-F\(n)-TITLE", "dashboard", title, fg: titleFG, bg: Pal.white, size: 15) }
    var subtitleSpec: ContrastSpec { ContrastSpec("DASH-F\(n)-SUB", "dashboard", subtitle, fg: subtitleFG, bg: Pal.white, size: 13) }
    var timeSpec: ContrastSpec { ContrastSpec("DASH-F\(n)-TIME", "dashboard", time, fg: timeFG, bg: Pal.white, size: 12) }
    var specs: [ContrastSpec] { [titleSpec, subtitleSpec, timeSpec] }
}

nonisolated struct SettingRow: Identifiable, Hashable, Sendable {
    let n: Int
    let label: String
    let labelFG: UInt32
    let value: String
    let valueFG: UInt32

    var id: Int { n }

    var labelSpec: ContrastSpec { ContrastSpec("SET-R\(n)-LABEL", "settings", label, fg: labelFG, bg: Pal.white, size: 17) }
    var valueSpec: ContrastSpec { ContrastSpec("SET-R\(n)-VALUE", "settings", value, fg: valueFG, bg: Pal.white, size: 17) }
    var specs: [ContrastSpec] { [labelSpec, valueSpec] }
}

nonisolated struct SummaryRow: Identifiable, Hashable, Sendable {
    let n: Int
    let label: String
    let labelFG: UInt32
    let value: String

    var id: Int { n }

    var labelSpec: ContrastSpec { ContrastSpec("CO-S\(n)-LABEL", "checkout", label, fg: labelFG, bg: Pal.white, size: 15) }
    var valueSpec: ContrastSpec { ContrastSpec("CO-S\(n)-VALUE", "checkout", value, fg: Pal.ink, bg: Pal.white, size: 15) }
    var specs: [ContrastSpec] { [labelSpec, valueSpec] }
}

// MARK: - Registry

nonisolated enum GroundTruth {

    /// Screens that have ground truth, in audit order. Also the values the app
    /// accepts in the AUDIT_SCREEN launch environment variable.
    static let screens = ["shop", "shop-detail", "dashboard", "settings", "checkout"]

    static func specs(for screen: String) -> [ContrastSpec] {
        all.filter { $0.screen == screen }
    }

    static func spec(_ id: String) -> ContrastSpec {
        guard let spec = byID[id] else { fatalError("No ground-truth spec with id \(id)") }
        return spec
    }

    static let all: [ContrastSpec] =
        [shop, shopDetail, dashboard, settings, checkout].flatMap { $0 }

    static let byID: [String: ContrastSpec] =
        Dictionary(uniqueKeysWithValues: all.map { ($0.id, $0) })

    // MARK: Shop (listing)

    static let products: [Product] = [
        Product(n: 1, name: "Aero Runner Shoes", price: "$129.00",
                titleFG: Pal.ink, priceFG: Pal.darkRed,
                badge: "NEW", badgeFG: Pal.white, badgeBG: Pal.sysBlue,
                ctaText: "Add to cart", ctaFG: Pal.white, ctaBG: Pal.darkBlue,
                inStock: true, swatch: 0xDCE6FF),
        Product(n: 2, name: "Trail Jacket", price: "$89.00",
                titleFG: Pal.text2, priceFG: Pal.sysGreen,
                badge: "SALE", badgeFG: Pal.white, badgeBG: Pal.sysRed,
                ctaText: "Add to cart", ctaFG: Pal.white, ctaBG: Pal.sysBlue,
                inStock: true, swatch: 0xD9F2E0),
        Product(n: 3, name: "Studio Headphones", price: "$199.00",
                titleFG: Pal.ink, priceFG: Pal.ink,
                badge: "BESTSELLER", badgeFG: Pal.black, badgeBG: Pal.sysYellow,
                ctaText: "Add to cart", ctaFG: Pal.white, ctaBG: Pal.brandNavy,
                inStock: true, swatch: 0xFFF1C2),
        Product(n: 4, name: "Canvas Tote", price: "$34.00",
                titleFG: Pal.text3, priceFG: Pal.sysGray,
                badge: "SOLD OUT", badgeFG: Pal.white, badgeBG: Pal.sysGray,
                ctaText: "Sold out", ctaFG: Pal.sysGray2, ctaBG: Pal.grouped,
                inStock: false, swatch: 0xEDEDED),
        Product(n: 5, name: "Ceramic Mug Set", price: "$42.00",
                titleFG: Pal.ink, priceFG: Pal.brandCoral,
                badge: "-30%", badgeFG: Pal.white, badgeBG: Pal.brandCoral,
                ctaText: "Add to cart", ctaFG: Pal.white, ctaBG: Pal.darkGreen,
                inStock: true, swatch: 0xFFE0DE),
        Product(n: 6, name: "Linen Shirt", price: "$58.00",
                titleFG: Pal.hint, priceFG: Pal.ink,
                badge: nil, badgeFG: Pal.white, badgeBG: Pal.white,
                ctaText: "Add to cart", ctaFG: Pal.sysBlue, ctaBG: Pal.white,
                inStock: true, swatch: 0xE4E4F5),
    ]

    private static let shop: [ContrastSpec] = {
        var specs: [ContrastSpec] = products.flatMap { $0.specs }
        specs += [
            // Hero over a gradient: no single correct ratio.
            ContrastSpec("SHOP-HERO", "shop", "Black Friday: up to 50% off",
                         fg: Pal.white, bg: Pal.sysOrange, size: 24, bold: true, measurable: false),
            ContrastSpec("SHOP-SEARCH-HINT", "shop", "Search shoes, brands and more",
                         fg: Pal.placeholder, bg: Pal.grouped, size: 17),
            ContrastSpec("SHOP-SECTION", "shop", "Recommended for you",
                         fg: Pal.ink, bg: Pal.white, size: 22, bold: true),
            ContrastSpec("SHOP-SHIPPING", "shop", "Free shipping on orders over $50",
                         fg: Pal.text3, bg: Pal.grouped, size: 13),
            ContrastSpec("SHOP-FOOTER", "shop", "© 2026 Aero Store · Terms · Returns",
                         fg: Pal.hint, bg: Pal.white, size: 12),
        ]
        return specs
    }()

    // MARK: Shop (product detail)

    private static let shopDetail: [ContrastSpec] = [
        ContrastSpec("DET-TITLE", "shop-detail", "Aero Runner Shoes", fg: Pal.ink, bg: Pal.white, size: 28, bold: true),
        ContrastSpec("DET-PRICE", "shop-detail", "$129.00", fg: Pal.darkRed, bg: Pal.white, size: 24, bold: true),
        ContrastSpec("DET-RATING", "shop-detail", "4.6 rating (1,240 reviews)", fg: Pal.sysBlue, bg: Pal.white, size: 14),
        ContrastSpec("DET-DESC", "shop-detail", "Lightweight knit upper with a responsive foam midsole, built for daily miles.",
                     fg: Pal.text2, bg: Pal.white, size: 15),
        ContrastSpec("DET-SIZE-LABEL", "shop-detail", "Select size", fg: Pal.text3, bg: Pal.white, size: 13),
        ContrastSpec("DET-STOCK", "shop-detail", "Only 3 left in stock", fg: Pal.sysOrange, bg: Pal.white, size: 13, bold: true),
        ContrastSpec("DET-DELIVERY", "shop-detail", "Arrives Thursday", fg: Pal.darkGreen, bg: Pal.white, size: 15),
        ContrastSpec("DET-ADD", "shop-detail", "Add to bag", fg: Pal.white, bg: Pal.darkBlue, size: 17, bold: true),
        ContrastSpec("DET-WISH", "shop-detail", "Save for later", fg: Pal.sysBlue, bg: Pal.grouped, size: 17),
        ContrastSpec("DET-GIFT", "shop-detail", "Gift wrap (unavailable)", fg: Pal.sysGray2, bg: Pal.grouped, size: 17, enabled: false),
        ContrastSpec("DET-RETURNS", "shop-detail", "Free returns within 30 days", fg: Pal.hint, bg: Pal.white, size: 12),
    ]

    // MARK: Dashboard

    static let kpis: [Kpi] = [
        Kpi(n: 1, label: "Revenue", labelFG: Pal.text2, value: "$48,210", valueFG: Pal.ink,
            delta: "+12.4%", deltaFG: Pal.sysGreen, cardBG: Pal.white),
        Kpi(n: 2, label: "Orders", labelFG: Pal.text3, value: "1,284", valueFG: Pal.brandNavy,
            delta: "-3.1%", deltaFG: Pal.sysRed, cardBG: Pal.white),
        Kpi(n: 3, label: "Customers", labelFG: Pal.text2, value: "9,402", valueFG: Pal.sysPurple,
            delta: "+5.0%", deltaFG: Pal.darkGreen, cardBG: Pal.white),
        Kpi(n: 4, label: "Conversion", labelFG: Pal.hint, value: "3.8%", valueFG: Pal.sysTeal,
            delta: "0.0%", deltaFG: Pal.sysGray, cardBG: Pal.grouped),
    ]

    static let chips: [StatusChip] = [
        StatusChip(n: 1, text: "Operational", fg: Pal.white, bg: Pal.darkGreen),
        StatusChip(n: 2, text: "Degraded", fg: Pal.black, bg: Pal.sysYellow),
        StatusChip(n: 3, text: "Outage", fg: Pal.white, bg: Pal.sysRed),
        StatusChip(n: 4, text: "Maintenance", fg: Pal.white, bg: Pal.sysGray),
    ]

    static let feed: [FeedItem] = [
        FeedItem(n: 1, title: "Order #1042 shipped", titleFG: Pal.ink,
                 subtitle: "Aero Runner Shoes to Pune", subtitleFG: Pal.text2, time: "2 min ago", timeFG: Pal.sysGray),
        FeedItem(n: 2, title: "New review posted", titleFG: Pal.ink,
                 subtitle: "5 stars on Studio Headphones", subtitleFG: Pal.text3, time: "14 min ago", timeFG: Pal.hint),
        FeedItem(n: 3, title: "Refund approved", titleFG: Pal.darkBlue,
                 subtitle: "Order #1017, $34.00", subtitleFG: Pal.text2, time: "1 hr ago", timeFG: Pal.text2),
        FeedItem(n: 4, title: "Low stock warning", titleFG: Pal.sysBlue,
                 subtitle: "Canvas Tote: 4 units left", subtitleFG: Pal.text2, time: "3 hr ago", timeFG: Pal.sysGray2),
        FeedItem(n: 5, title: "Campaign finished", titleFG: Pal.ink,
                 subtitle: "Spring promo reached 41k views", subtitleFG: Pal.hint, time: "Yesterday", timeFG: Pal.text3),
        FeedItem(n: 6, title: "Payout scheduled", titleFG: Pal.darkGreen,
                 subtitle: "$12,480 arrives Friday", subtitleFG: Pal.text2, time: "2 days ago", timeFG: Pal.text2),
    ]

    private static let dashboard: [ContrastSpec] = {
        var specs: [ContrastSpec] = []
        specs += kpis.flatMap { $0.specs }
        specs += chips.map { $0.spec }
        specs += feed.flatMap { $0.specs }
        specs += [
            // Dark "alerts" card on 1C1C1E.
            ContrastSpec("DASH-A1", "dashboard", "System health", fg: Pal.sysGray2, bg: Pal.ink, size: 15),
            ContrastSpec("DASH-A2", "dashboard", "3 incidents resolved", fg: Pal.text3, bg: Pal.ink, size: 15),
            ContrastSpec("DASH-A3", "dashboard", "View incident log", fg: Pal.darkBlue, bg: Pal.ink, size: 15),
            ContrastSpec("DASH-A4", "dashboard", "2 warnings", fg: Pal.sysRed, bg: Pal.ink, size: 15),
            ContrastSpec("DASH-A5", "dashboard", "Escalate to on-call", fg: Pal.darkRed, bg: Pal.ink, size: 15),
            // Chart title over a gradient: no single correct ratio.
            ContrastSpec("DASH-CHART", "dashboard", "Revenue trend, last 7 days",
                         fg: Pal.white, bg: Pal.sysGreen, size: 15, bold: true, measurable: false),
        ]
        return specs
    }()

    // MARK: Settings

    static let settingRows: [SettingRow] = [
        SettingRow(n: 1, label: "Name", labelFG: Pal.ink, value: "Akshay K.", valueFG: Pal.text2),
        SettingRow(n: 2, label: "Email", labelFG: Pal.ink, value: "akshay@example.com", valueFG: Pal.text3),
        SettingRow(n: 3, label: "Phone", labelFG: Pal.ink, value: "+1 555 0100", valueFG: Pal.hint),
        SettingRow(n: 4, label: "Language", labelFG: Pal.text2, value: "English", valueFG: Pal.text2),
        SettingRow(n: 5, label: "Region", labelFG: Pal.ink, value: "United States", valueFG: Pal.sysGray),
        SettingRow(n: 6, label: "Currency", labelFG: Pal.ink, value: "USD", valueFG: Pal.ink),
        SettingRow(n: 7, label: "Time zone", labelFG: Pal.text3, value: "GMT+5:30", valueFG: Pal.darkBlue),
    ]

    private static let settings: [ContrastSpec] = {
        var specs: [ContrastSpec] = settingRows.flatMap { $0.specs }
        specs += [
            ContrastSpec("SET-H1", "settings", "ACCOUNT", fg: Pal.hint, bg: Pal.grouped, size: 13),
            ContrastSpec("SET-H2", "settings", "NOTIFICATIONS", fg: Pal.hint, bg: Pal.grouped, size: 13),
            ContrastSpec("SET-H3", "settings", "ABOUT", fg: Pal.text2, bg: Pal.grouped, size: 13),
            ContrastSpec("SET-F2", "settings", "Choose which alerts reach you.", fg: Pal.text3, bg: Pal.grouped, size: 13),
            ContrastSpec("SET-T1", "settings", "Push notifications", fg: Pal.ink, bg: Pal.white, size: 17),
            ContrastSpec("SET-T2", "settings", "Email digest", fg: Pal.text2, bg: Pal.white, size: 17),
            ContrastSpec("SET-T3", "settings", "Marketing offers", fg: Pal.text3, bg: Pal.white, size: 17),
            ContrastSpec("SET-UPGRADE", "settings", "Upgrade to Pro", fg: Pal.white, bg: Pal.brandCoral, size: 17, bold: true),
            ContrastSpec("SET-RESTORE", "settings", "Restore purchases", fg: Pal.sysGray2, bg: Pal.white, size: 17, enabled: false),
            ContrastSpec("SET-SIGNOUT", "settings", "Sign out", fg: Pal.darkRed, bg: Pal.white, size: 17),
            ContrastSpec("SET-DELETE", "settings", "Delete account", fg: Pal.sysRed, bg: Pal.white, size: 17),
            ContrastSpec("SET-VERSION", "settings", "Version 2.4.1 (build 318)", fg: Pal.placeholder, bg: Pal.grouped, size: 12),
        ]
        return specs
    }()

    // MARK: Checkout

    static let summaryRows: [SummaryRow] = [
        SummaryRow(n: 1, label: "Subtotal", labelFG: Pal.text2, value: "$194.50"),
        SummaryRow(n: 2, label: "Shipping", labelFG: Pal.text3, value: "$9.99"),
        SummaryRow(n: 3, label: "Tax", labelFG: Pal.text2, value: "$10.01"),
    ]

    private static let checkout: [ContrastSpec] = {
        var specs: [ContrastSpec] = summaryRows.flatMap { $0.specs }
        specs += [
            ContrastSpec("CO-STEP", "checkout", "Step 2 of 3 · Payment", fg: Pal.hint, bg: Pal.white, size: 13),
            ContrastSpec("CO-H1", "checkout", "Payment", fg: Pal.ink, bg: Pal.white, size: 28, bold: true),
            ContrastSpec("CO-L1", "checkout", "Card number", fg: Pal.text2, bg: Pal.white, size: 13),
            ContrastSpec("CO-L2", "checkout", "Expiry date", fg: Pal.text3, bg: Pal.white, size: 13),
            ContrastSpec("CO-L3", "checkout", "Security code", fg: Pal.ink, bg: Pal.white, size: 13),
            ContrastSpec("CO-ERR", "checkout", "Enter a valid card number", fg: Pal.sysRed, bg: Pal.white, size: 13),
            ContrastSpec("CO-OK", "checkout", "Promo code SAVE10 applied", fg: Pal.darkGreen, bg: Pal.white, size: 13),
            ContrastSpec("CO-TOTAL-L", "checkout", "Total", fg: Pal.ink, bg: Pal.white, size: 17, bold: true),
            ContrastSpec("CO-TOTAL", "checkout", "$214.50", fg: Pal.ink, bg: Pal.white, size: 22, bold: true),
            ContrastSpec("CO-AGREE", "checkout", "I agree to the terms", fg: Pal.ink, bg: Pal.white, size: 15),
            ContrastSpec("CO-PAY", "checkout", "Pay $214.50", fg: Pal.white, bg: Pal.darkBlue, size: 17, bold: true),
            ContrastSpec("CO-PROMO", "checkout", "Apply promo", fg: Pal.sysBlue, bg: Pal.white, size: 15),
            ContrastSpec("CO-GUEST", "checkout", "Continue as guest", fg: Pal.brandCoral, bg: Pal.white, size: 17),
            ContrastSpec("CO-PLACE", "checkout", "Place order", fg: Pal.sysGray2, bg: Pal.grouped, size: 17, enabled: false),
            ContrastSpec("CO-TERMS", "checkout", "Terms of Service", fg: Pal.sysBlue, bg: Pal.white, size: 13),
            ContrastSpec("CO-PRIV", "checkout", "Privacy Policy", fg: Pal.darkBlue, bg: Pal.white, size: 13),
            ContrastSpec("CO-LEGAL", "checkout", "By placing your order you agree to our terms and conditions.",
                         fg: Pal.text3, bg: Pal.white, size: 11),
        ]
        return specs
    }()
}

//
//  ShopScreens.swift
//  E-commerce: a lazily loaded product listing and a product detail page.
//

import SwiftUI

struct ShopScreen: View {
    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                hero
                searchField
                categoryChips
                HStack {
                    SpecText(spec: GroundTruth.spec("SHOP-SECTION"))
                    Spacer()
                    RuleControl(spec: RuleGroundTruth.control("SHOP-TRAIT-SEEALL"))
                }
                ForEach(GroundTruth.products) { product in
                    ProductCard(product: product)
                }
                deliveryNotes
                shippingNote
                SpecText(spec: GroundTruth.spec("SHOP-FOOTER"))
                    .frame(maxWidth: .infinity)
                    .padding(.top, 8)
            }
            .padding(16)
        }
        .background(Color(hex: Pal.white))
        .navigationTitle("Shop")
        .navigationBarTitleDisplayMode(.inline)
    }

    /// Text over a gradient: deliberately has no single correct contrast ratio.
    private var hero: some View {
        let spec = GroundTruth.spec("SHOP-HERO")
        return SpecText(spec: spec)
            .frame(maxWidth: .infinity, minHeight: 96, alignment: .leading)
            .padding(.horizontal, 16)
            .background(
                LinearGradient(colors: [Color(hex: Pal.sysOrange), Color(hex: Pal.sysYellow)],
                               startPoint: .leading, endPoint: .trailing),
                in: RoundedRectangle(cornerRadius: 14))
    }

    private var searchField: some View {
        let spec = GroundTruth.spec("SHOP-SEARCH-HINT")
        return HStack {
            SpecText(spec: spec)
            Spacer()
        }
        .padding(12)
        .background(spec.backgroundColor, in: RoundedRectangle(cornerRadius: 10))
    }

    /// Category chips in fixed 120pt columns: one truncates, one is cut off, one wraps.
    private var categoryChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: 12) {
                RuleControl(spec: RuleGroundTruth.control("SHOP-TC-ELLIPSIS"))
                RuleControl(spec: RuleGroundTruth.control("SHOP-TC-HARD"))
                RuleControl(spec: RuleGroundTruth.control("SHOP-TC-WRAP"))
            }
        }
    }

    /// Delivery notes (one fixed-size, one scaling), a deals link, and a gift
    /// control that is visible but hidden from accessibility.
    private var deliveryNotes: some View {
        VStack(alignment: .leading, spacing: 8) {
            RuleControl(spec: RuleGroundTruth.control("SHOP-DT-FIXED"))
            RuleControl(spec: RuleGroundTruth.control("SHOP-DT-SCALE"))
            RuleControl(spec: RuleGroundTruth.control("SHOP-TRAIT-DEALS"))
            RuleControl(spec: RuleGroundTruth.control("SHOP-HIDDEN-GIFT"))
        }
    }

    private var shippingNote: some View {
        let spec = GroundTruth.spec("SHOP-SHIPPING")
        return HStack {
            SpecText(spec: spec)
            Spacer()
        }
        .padding(12)
        .background(spec.backgroundColor, in: RoundedRectangle(cornerRadius: 10))
    }
}

struct ProductCard: View {
    let product: Product

    var body: some View {
        SpecCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 12) {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(hex: product.swatch))
                        .frame(width: 72, height: 72)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 6) {
                        SpecText(spec: product.titleSpec)
                        SpecText(spec: product.priceSpec)
                        if let badge = product.badgeSpec {
                            SpecBadge(spec: badge)
                        }
                    }
                    Spacer(minLength: 0)
                    RuleControl(spec: RuleGroundTruth.control("SHOP-FAV-\(product.n)"))
                }
                SpecButton(spec: product.ctaSpec)
            }
        }
    }
}

struct ProductDetailScreen: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(hex: 0xDCE6FF))
                    .frame(height: 220)
                    .accessibilityHidden(true)

                imageActions

                SpecText(spec: GroundTruth.spec("DET-TITLE"))
                SpecText(spec: GroundTruth.spec("DET-PRICE"))
                SpecText(spec: GroundTruth.spec("DET-RATING"))
                SpecText(spec: GroundTruth.spec("DET-DESC"))
                RuleControl(spec: RuleGroundTruth.control("DET-TC-ELLIPSIS"))
                SpecText(spec: GroundTruth.spec("DET-SIZE-LABEL"))
                sizePicker
                RuleControl(spec: RuleGroundTruth.control("DET-TRAIT-TAP"))
                SpecText(spec: GroundTruth.spec("DET-STOCK"))
                SpecText(spec: GroundTruth.spec("DET-DELIVERY"))

                SpecButton(spec: GroundTruth.spec("DET-ADD"))
                SpecButton(spec: GroundTruth.spec("DET-WISH"))
                SpecButton(spec: GroundTruth.spec("DET-GIFT"))

                RuleControl(spec: RuleGroundTruth.control("DET-DT-FIXED"))
                RuleControl(spec: RuleGroundTruth.control("DET-DT-SCALE"))
                RuleControl(spec: RuleGroundTruth.control("DET-TRAIT-FAKE"))
                SpecText(spec: GroundTruth.spec("DET-RETURNS"))
            }
            .padding(16)
        }
        .background(Color(hex: Pal.white))
        .navigationTitle("Aero Runner Shoes")
        .navigationBarTitleDisplayMode(.inline)
    }

    /// Share / favourite / compare / zoom actions under the product image,
    /// plus a zoom control that is hidden from accessibility.
    private var imageActions: some View {
        HStack(spacing: 12) {
            RuleControl(spec: RuleGroundTruth.control("DET-ICON-SHARE"))
            RuleControl(spec: RuleGroundTruth.control("DET-ICON-FAV"))
            RuleControl(spec: RuleGroundTruth.control("DET-ICON-COMPARE"))
            RuleControl(spec: RuleGroundTruth.control("DET-ICON-ZOOM"))
            Spacer()
            RuleControl(spec: RuleGroundTruth.control("DET-HIDDEN-ZOOM"))
        }
    }

    /// Plain size chips. Not part of the ground truth: they use system colours,
    /// so findings on them show up as "outside the ground truth" in the report.
    private var sizePicker: some View {
        HStack(spacing: 8) {
            ForEach(["S", "M", "L", "XL"], id: \.self) { size in
                Text(size)
                    .frame(width: 44, height: 44)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(hex: Pal.border)))
                    .accessibilityIdentifier("det-size-\(size)")
            }
        }
    }
}

//
//  CheckoutScreen.swift
//  A payment step: labelled inputs, a validation error, order summary, primary /
//  secondary / disabled buttons, links and legal text.
//

import SwiftUI

struct CheckoutScreen: View {
    @State private var card = ""
    @State private var expiry = ""
    @State private var cvv = ""
    @State private var agreed = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                SpecText(spec: GroundTruth.spec("CO-STEP"))
                SpecText(spec: GroundTruth.spec("CO-H1"))

                SpecText(spec: GroundTruth.spec("CO-L1"))
                // Real text fields use system colours; they are outside the
                // ground truth and any findings on them are reported separately.
                TextField("1234 5678 9012 3456", text: $card)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityIdentifier("co-field-card")
                SpecText(spec: GroundTruth.spec("CO-ERR"))

                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 6) {
                        SpecText(spec: GroundTruth.spec("CO-L2"))
                        TextField("MM / YY", text: $expiry)
                            .textFieldStyle(.roundedBorder)
                            .accessibilityIdentifier("co-field-expiry")
                    }
                    VStack(alignment: .leading, spacing: 6) {
                        SpecText(spec: GroundTruth.spec("CO-L3"))
                        TextField("123", text: $cvv)
                            .textFieldStyle(.roundedBorder)
                            .accessibilityIdentifier("co-field-cvv")
                    }
                }

                HStack {
                    SpecButton(spec: GroundTruth.spec("CO-PROMO"), fullWidth: false)
                    Spacer()
                }
                SpecText(spec: GroundTruth.spec("CO-OK"))

                summary
                deliverySection

                Toggle(isOn: $agreed) {
                    SpecText(spec: GroundTruth.spec("CO-AGREE"), identified: false)
                }
                .accessibilityIdentifier("CO-AGREE")

                SpecButton(spec: GroundTruth.spec("CO-PAY"))
                SpecButton(spec: GroundTruth.spec("CO-PLACE"))
                SpecButton(spec: GroundTruth.spec("CO-GUEST"))

                HStack(spacing: 16) {
                    SpecText(spec: GroundTruth.spec("CO-TERMS"))
                    SpecText(spec: GroundTruth.spec("CO-PRIV"))
                }
                SpecText(spec: GroundTruth.spec("CO-LEGAL"))
            }
            .padding(16)
        }
        .background(Color(hex: Pal.white))
        .navigationTitle("Checkout")
        .navigationBarTitleDisplayMode(.inline)
    }

    /// Address and delivery controls: icon buttons, delivery notes (one fixed
    /// size, one scaling), courier notes (one cut off, one wraps), a text link,
    /// and a card-brand picker hidden from accessibility.
    private var deliverySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                RuleControl(spec: RuleGroundTruth.control("CO-ICON-SCAN"))
                RuleControl(spec: RuleGroundTruth.control("CO-ICON-REMOVE"))
                RuleControl(spec: RuleGroundTruth.control("CO-ICON-EDIT"))
                Spacer()
                RuleControl(spec: RuleGroundTruth.control("CO-HIDDEN-BRANDS"))
            }
            RuleControl(spec: RuleGroundTruth.control("CO-DT-FIXED"))
            RuleControl(spec: RuleGroundTruth.control("CO-DT-SCALE"))
            RuleControl(spec: RuleGroundTruth.control("CO-TC-HARD"))
            RuleControl(spec: RuleGroundTruth.control("CO-TC-WRAP"))
            RuleControl(spec: RuleGroundTruth.control("CO-TRAIT-CHANGE"))
        }
    }

    private var summary: some View {
        VStack(spacing: 8) {
            ForEach(GroundTruth.summaryRows) { row in
                HStack {
                    SpecText(spec: row.labelSpec)
                    Spacer()
                    SpecText(spec: row.valueSpec)
                }
            }
            Divider()
            HStack {
                SpecText(spec: GroundTruth.spec("CO-TOTAL-L"))
                Spacer()
                SpecText(spec: GroundTruth.spec("CO-TOTAL"))
            }
        }
        .padding(.vertical, 6)
    }
}

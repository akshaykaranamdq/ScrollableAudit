//
//  SettingsScreen.swift
//  A grouped settings list: account rows, toggles, section headers and
//  footers, and a stack of actions including destructive and disabled ones.
//

import SwiftUI

struct SettingsScreen: View {
    @State private var push = true
    @State private var digest = false
    @State private var marketing = false

    var body: some View {
        List {
            Section {
                ForEach(GroundTruth.settingRows) { row in
                    HStack {
                        SpecText(spec: row.labelSpec)
                        Spacer()
                        SpecText(spec: row.valueSpec)
                    }
                    .listRowBackground(Color(hex: Pal.white))
                }
            } header: {
                SpecText(spec: GroundTruth.spec("SET-H1")).textCase(nil)
            }

            Section {
                toggle($push, id: "SET-T1")
                toggle($digest, id: "SET-T2")
                toggle($marketing, id: "SET-T3")
            } header: {
                SpecText(spec: GroundTruth.spec("SET-H2")).textCase(nil)
            } footer: {
                SpecText(spec: GroundTruth.spec("SET-F2"))
            }

            Section {
                HStack(spacing: 12) {
                    RuleControl(spec: RuleGroundTruth.control("SET-ICON-HELP"))
                    RuleControl(spec: RuleGroundTruth.control("SET-ICON-INFO"))
                    Spacer()
                }
                .listRowBackground(Color(hex: Pal.white))
                supportRow("SET-DT-FIXED")
                supportRow("SET-DT-SCALE")
                supportRow("SET-TC-ELLIPSIS")
                supportRow("SET-TC-WRAP")
                supportRow("SET-TRAIT-PRIVACY")
                supportRow("SET-TRAIT-TERMS")
                supportRow("SET-TRAIT-FAKE")
            } header: {
                Text("SUPPORT")
                    .font(.footnote)
                    .foregroundStyle(Color(hex: Pal.text2))
                    .textCase(nil)
            }

            Section {
                SpecButton(spec: GroundTruth.spec("SET-UPGRADE"))
                    .listRowBackground(Color(hex: Pal.white))
                SpecButton(spec: GroundTruth.spec("SET-RESTORE"))
                    .listRowBackground(Color(hex: Pal.white))
                SpecButton(spec: GroundTruth.spec("SET-SIGNOUT"))
                    .listRowBackground(Color(hex: Pal.white))
                SpecButton(spec: GroundTruth.spec("SET-DELETE"))
                    .listRowBackground(Color(hex: Pal.white))
            } header: {
                SpecText(spec: GroundTruth.spec("SET-H3")).textCase(nil)
            } footer: {
                SpecText(spec: GroundTruth.spec("SET-VERSION"))
                    .frame(maxWidth: .infinity)
                    .padding(.top, 8)
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Color(hex: Pal.grouped))
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func supportRow(_ id: String) -> some View {
        HStack {
            RuleControl(spec: RuleGroundTruth.control(id))
            Spacer()
        }
        .listRowBackground(Color(hex: Pal.white))
    }

    /// The Toggle carries the identifier, so the switch element is what the audit reports.
    private func toggle(_ isOn: Binding<Bool>, id: String) -> some View {
        let spec = GroundTruth.spec(id)
        return Toggle(isOn: isOn) {
            SpecText(spec: spec, identified: false)
        }
        .accessibilityIdentifier(spec.id)
        .listRowBackground(Color(hex: Pal.white))
    }
}

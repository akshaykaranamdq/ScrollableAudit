//
//  DashboardScreen.swift
//  KPI cards, status chips, a dark alerts card, a chart over a gradient, and
//  an activity feed: the mixed-surface layout typical of admin and analytics apps.
//

import SwiftUI

struct DashboardScreen: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                toolbarRow
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible())], spacing: 12) {
                    ForEach(GroundTruth.kpis) { kpi in
                        SpecCard(background: kpi.cardBG) {
                            VStack(alignment: .leading, spacing: 4) {
                                SpecText(spec: kpi.labelSpec)
                                SpecText(spec: kpi.valueSpec)
                                SpecText(spec: kpi.deltaSpec)
                            }
                        }
                    }
                }

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 130), spacing: 8)], alignment: .leading, spacing: 8) {
                    ForEach(GroundTruth.chips) { chip in
                        SpecBadge(spec: chip.spec)
                    }
                }

                chart
                reportCards
                alerts
                feed
                HStack {
                    RuleControl(spec: RuleGroundTruth.control("DASH-TRAIT-ALL"))
                    Spacer()
                    RuleControl(spec: RuleGroundTruth.control("DASH-TRAIT-OK"))
                }
                // Floating "add widget" button that never reached the accessibility tree.
                HStack {
                    Spacer()
                    RuleControl(spec: RuleGroundTruth.control("DASH-HIDDEN-FAB"))
                }
            }
            .padding(16)
        }
        .background(Color(hex: Pal.grouped))
        .navigationTitle("Dashboard")
        .navigationBarTitleDisplayMode(.inline)
    }

    /// Refresh / filter / export / settings icons, with a "last updated" note.
    private var toolbarRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                RuleControl(spec: RuleGroundTruth.control("DASH-ICON-1"))
                RuleControl(spec: RuleGroundTruth.control("DASH-ICON-2"))
                RuleControl(spec: RuleGroundTruth.control("DASH-ICON-3"))
                RuleControl(spec: RuleGroundTruth.control("DASH-ICON-4"))
            }
            RuleControl(spec: RuleGroundTruth.control("DASH-DT-FIXED"))
            RuleControl(spec: RuleGroundTruth.control("DASH-DT-SCALE"))
        }
    }

    /// Two report titles in narrow 130pt columns: one truncates, one wraps.
    private var reportCards: some View {
        SpecCard {
            HStack(alignment: .top, spacing: 16) {
                RuleControl(spec: RuleGroundTruth.control("DASH-TC-ELLIPSIS"))
                RuleControl(spec: RuleGroundTruth.control("DASH-TC-WRAP"))
            }
        }
    }

    /// Text over a gradient: deliberately has no single correct contrast ratio.
    private var chart: some View {
        let spec = GroundTruth.spec("DASH-CHART")
        return SpecText(spec: spec)
            .frame(maxWidth: .infinity, minHeight: 120, alignment: .topLeading)
            .padding(14)
            .background(
                LinearGradient(colors: [Color(hex: Pal.sysGreen), Color(hex: Pal.sysTeal)],
                               startPoint: .topLeading, endPoint: .bottomTrailing),
                in: RoundedRectangle(cornerRadius: 12))
    }

    private var alerts: some View {
        SpecCard(background: Pal.ink) {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(["DASH-A1", "DASH-A2", "DASH-A3", "DASH-A4", "DASH-A5"], id: \.self) { id in
                    SpecText(spec: GroundTruth.spec(id))
                }
            }
        }
    }

    private var feed: some View {
        SpecCard {
            // Plain VStack: only 6 rows, and SwiftUI may not expose the first
            // row of a lazy stack to accessibility.
            VStack(alignment: .leading, spacing: 14) {
                ForEach(GroundTruth.feed) { item in
                    VStack(alignment: .leading, spacing: 2) {
                        SpecText(spec: item.titleSpec)
                        SpecText(spec: item.subtitleSpec)
                        SpecText(spec: item.timeSpec)
                    }
                }
            }
        }
    }
}

//
//  ContentView.swift
//  ScrollableAudit
//
//  Home menu for the audit lab. A UI test can skip the menu and open a screen
//  directly by launching with the AUDIT_SCREEN environment variable set to one
//  of AuditRoute's raw values (shop, shop-detail, dashboard, settings,
//  checkout, legacy).
//

import SwiftUI

enum AuditRoute: String, CaseIterable, Hashable {
    case shop
    case shopDetail = "shop-detail"
    case dashboard
    case settings
    case checkout
    case legacy

    var title: String {
        switch self {
        case .shop: "Shop: product listing"
        case .shopDetail: "Shop: product detail"
        case .dashboard: "Dashboard"
        case .settings: "Settings"
        case .checkout: "Checkout"
        case .legacy: "Legacy 20-row list"
        }
    }

    @ViewBuilder
    var destination: some View {
        switch self {
        case .shop: ShopScreen()
        case .shopDetail: ProductDetailScreen()
        case .dashboard: DashboardScreen()
        case .settings: SettingsScreen()
        case .checkout: CheckoutScreen()
        case .legacy: LegacyListScreen()
        }
    }
}

struct ContentView: View {
    @State private var path: [AuditRoute]

    init() {
        let launch = ProcessInfo.processInfo.environment["AUDIT_SCREEN"]
            .flatMap(AuditRoute.init(rawValue:))
        _path = State(initialValue: launch.map { [$0] } ?? [])
    }

    var body: some View {
        NavigationStack(path: $path) {
            List(AuditRoute.allCases, id: \.self) { route in
                NavigationLink(value: route) {
                    Text(route.title)
                }
                .accessibilityIdentifier("menu-\(route.rawValue)")
            }
            .navigationTitle("Audit Lab")
            .navigationDestination(for: AuditRoute.self) { route in
                route.destination
            }
        }
        // Light mode keeps every system surface deterministic, so the ground
        // truth colours are exactly what is drawn.
        .preferredColorScheme(.light)
    }
}

#Preview {
    ContentView()
}

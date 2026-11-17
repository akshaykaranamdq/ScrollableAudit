//
//  SpecViews.swift
//
//  Small building blocks that draw a ContrastSpec exactly as specified:
//  the spec's colours, size and weight, and its accessibilityIdentifier.
//
//  Sizes scale with Dynamic Type (ScaledMetric), so contrast specs are CLEAN
//  for the Dynamic Type rule. The only Dynamic Type defects in the app are the
//  deliberate ones in ControlSpec, which keeps that rule's answer key exact.
//

import SwiftUI

extension Color {
    init(hex: UInt32) {
        self.init(red: Double((hex >> 16) & 0xFF) / 255.0,
                  green: Double((hex >> 8) & 0xFF) / 255.0,
                  blue: Double(hex & 0xFF) / 255.0)
    }
}

extension ContrastSpec {
    var foregroundColor: Color { Color(hex: foreground) }
    var backgroundColor: Color { Color(hex: background) }
}

/// Applies the spec's size and weight, scaled with the user's text size.
struct SpecFont: ViewModifier {
    private let spec: ContrastSpec
    @ScaledMetric private var size: CGFloat

    init(_ spec: ContrastSpec) {
        self.spec = spec
        _size = ScaledMetric(wrappedValue: CGFloat(spec.size), relativeTo: .body)
    }

    func body(content: Content) -> some View {
        content.font(.system(size: size, weight: spec.bold ? .bold : .regular))
    }
}

extension View {
    func specFont(_ spec: ContrastSpec) -> some View { modifier(SpecFont(spec)) }
}

/// Text drawn with a spec's colour, size and weight. The container behind it
/// must already be the spec's background colour.
struct SpecText: View {
    let spec: ContrastSpec
    /// False when a parent control (a Toggle, say) carries the identifier.
    var identified = true

    var body: some View {
        Text(spec.text)
            .specFont(spec)
            .foregroundStyle(spec.foregroundColor)
            .accessibilityIdentifier(identified ? spec.id : "")
    }
}

/// Small pill with its own background (status chips, product badges).
struct SpecBadge: View {
    let spec: ContrastSpec

    var body: some View {
        Text(spec.text)
            .specFont(spec)
            .foregroundStyle(spec.foregroundColor)
            .accessibilityIdentifier(spec.id)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(spec.backgroundColor, in: Capsule())
    }
}

/// Button that shows its title in exactly the spec's colours. Disabled buttons
/// are NOT dimmed by SwiftUI, so the measured ratio stays what the spec says.
struct SpecButton: View {
    let spec: ContrastSpec
    var fullWidth = true
    var action: () -> Void = {}

    var body: some View {
        Button(action: action) {
            Text(spec.text)
                .specFont(spec)
                .foregroundStyle(spec.foregroundColor)
                .frame(maxWidth: fullWidth ? .infinity : nil, minHeight: 44)
                .padding(.horizontal, 16)
                .background(spec.backgroundColor, in: RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color(hex: Pal.border), lineWidth: 1))
        }
        .buttonStyle(NoDimButtonStyle())
        .disabled(!spec.enabled)
        .accessibilityIdentifier(spec.id)
    }
}

/// Returns the label untouched, so SwiftUI applies no automatic disabled dimming.
struct NoDimButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
    }
}

/// Card with an explicit background, so text on it has a known backdrop.
struct SpecCard<Content: View>: View {
    var background: UInt32 = Pal.white
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(hex: background), in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(hex: Pal.border), lineWidth: 1))
    }
}

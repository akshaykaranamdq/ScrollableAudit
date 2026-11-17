//
//  RuleControlView.swift
//
//  Draws a ControlSpec in exactly the way its `kind` describes, so the audit
//  rule it targets has a known right answer. Text is ink on white (passes
//  contrast) and the controls are otherwise well formed, so each one is
//  defective in the single way its spec says.
//

import SwiftUI

struct RuleControl: View {
    let spec: ControlSpec

    var body: some View {
        switch spec.kind {
        case .iconButton(let side, let labelled):
            iconButton(side: side, labelled: labelled)

        case .fixedFontText(let size):
            // Fixed point size: does not scale with Dynamic Type.
            Text(spec.text)
                .font(.system(size: size))
                .foregroundStyle(Color(hex: Pal.ink))
                .accessibilityIdentifier(spec.id)

        case .scalingText:
            Text(spec.text)
                .font(.footnote)
                .foregroundStyle(Color(hex: Pal.ink))
                .accessibilityIdentifier(spec.id)

        case .clippedText(let width, let mode):
            clipped(width: width, mode: mode)

        case .wrappingText(let width):
            Text(spec.text)
                .font(.footnote)
                .foregroundStyle(Color(hex: Pal.ink))
                .frame(width: width, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier(spec.id)

        case .tapText(let buttonTrait):
            tapText(buttonTrait: buttonTrait)

        case .fakeButton:
            // Claims to be a button, does nothing.
            Text(spec.text)
                .font(.body)
                .foregroundStyle(Color(hex: Pal.ink))
                .padding(.vertical, 12)
                .accessibilityAddTraits(.isButton)
                .accessibilityIdentifier(spec.id)

        case .hiddenControl:
            // Visible and tappable, but not exposed to accessibility.
            ZStack {
                Circle().fill(Color(hex: Pal.brandNavy))
                Image(systemName: spec.symbol).foregroundStyle(Color(hex: Pal.white))
            }
            .frame(width: 44, height: 44)
            .onTapGesture {}
            .accessibilityHidden(true)
        }
    }

    // MARK: Icon button

    /// Icon-only button of a given size. The symbol is hidden from
    /// accessibility, so the only accessible name is the label, when given.
    @ViewBuilder
    private func iconButton(side: Double, labelled: Bool) -> some View {
        let button = Button(action: {}) {
            ZStack {
                Circle().fill(Color(hex: Pal.grouped))
                Image(systemName: spec.symbol)
                    .font(.system(size: max(10, side * 0.4)))
                    .foregroundStyle(Color(hex: Pal.ink))
                    .accessibilityHidden(true)
            }
            .frame(width: side, height: side)
        }
        .buttonStyle(NoDimButtonStyle())
        .accessibilityIdentifier(spec.id)

        if labelled {
            button.accessibilityLabel(spec.text)
        } else {
            button
        }
    }

    // MARK: Clipped text

    @ViewBuilder
    private func clipped(width: Double, mode: ControlSpec.ClipMode) -> some View {
        switch mode {
        case .ellipsis:
            Text(spec.text)
                .font(.footnote)
                .foregroundStyle(Color(hex: Pal.ink))
                .lineLimit(1)
                .frame(width: width, alignment: .leading)
                .accessibilityIdentifier(spec.id)
        case .hard:
            // Takes its full two-line height, then the frame cuts it off.
            Text(spec.text)
                .font(.footnote)
                .foregroundStyle(Color(hex: Pal.ink))
                .frame(width: width, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
                .frame(width: width, height: 16, alignment: .top)
                .clipped()
                .accessibilityIdentifier(spec.id)
        }
    }

    // MARK: Tappable text

    @ViewBuilder
    private func tapText(buttonTrait: Bool) -> some View {
        let text = Text(spec.text)
            .font(.body)
            .foregroundStyle(Color(hex: Pal.darkBlue))
            .padding(.vertical, 12)
            .contentShape(Rectangle())
            .onTapGesture {}
            .accessibilityIdentifier(spec.id)

        if buttonTrait {
            text.accessibilityAddTraits(.isButton)
        } else {
            text
        }
    }
}

import SwiftUI
import UIKit

// Shared building blocks for the Keepshire look: a grouped background with a
// soft brand tint, raised cards, gradient primary buttons, tinted icon tiles,
// and rounded headings. Screens compose these instead of styling inline, so
// the whole app stays consistent with the splash and Security Setup.

// MARK: - Background

/// Grouped background with the icon's teal-to-green sweep fading in from the top.
struct KeepshireBackground: View {
    var body: some View {
        ZStack(alignment: .top) {
            Color(.systemGroupedBackground)
            LinearGradient(
                colors: [
                    KeepshireTheme.glowTeal.opacity(0.16),
                    KeepshireTheme.glowGreen.opacity(0.05),
                    .clear
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 380)
        }
        .ignoresSafeArea()
    }
}

extension View {
    /// Places the brand background behind a screen. For `List` and `Form`,
    /// pass `hidesScrollBackground` so the system grouped fill does not cover it.
    func keepshireBackground(hidesScrollBackground: Bool = false) -> some View {
        modifier(KeepshireBackgroundModifier(hidesScrollBackground: hidesScrollBackground))
    }

    /// Raised card: secondary grouped fill, continuous corners, soft shadow.
    func keepshireCard(cornerRadius: CGFloat = 18, padding: CGFloat? = 16) -> some View {
        modifier(KeepshireCardModifier(cornerRadius: cornerRadius, padding: padding))
    }
}

private struct KeepshireBackgroundModifier: ViewModifier {
    let hidesScrollBackground: Bool

    func body(content: Content) -> some View {
        content
            .scrollContentBackground(hidesScrollBackground ? .hidden : .automatic)
            .background(KeepshireBackground())
    }
}

private struct KeepshireCardModifier: ViewModifier {
    let cornerRadius: CGFloat
    let padding: CGFloat?

    func body(content: Content) -> some View {
        content
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(padding ?? 0)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Color(.secondarySystemGroupedBackground))
                    .shadow(color: .black.opacity(0.05), radius: 8, y: 3)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(Color(.separator).opacity(0.35), lineWidth: 0.5)
            )
    }
}

// MARK: - Buttons

/// Full-width gradient button for the main action on a screen.
struct KeepshirePrimaryButtonStyle: ButtonStyle {
    var tint: AnyShapeStyle = AnyShapeStyle(KeepshireTheme.actionGradient)
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.headline, design: .rounded))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 54)
            .padding(.horizontal, 16)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(isEnabled ? tint : AnyShapeStyle(Color(.systemGray3)))
            )
            .shadow(color: KeepshireTheme.glowTeal.opacity(isEnabled ? 0.25 : 0), radius: 10, y: 5)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .opacity(configuration.isPressed ? 0.9 : 1)
            .animation(.smooth(duration: 0.15), value: configuration.isPressed)
    }
}

/// Tinted, lower-emphasis button that sits beside or below a primary one.
struct KeepshireSecondaryButtonStyle: ButtonStyle {
    var tint: Color = KeepshireTheme.accent

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.subheadline, design: .rounded, weight: .semibold))
            .foregroundStyle(tint)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 46)
            .padding(.horizontal, 12)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(tint.opacity(0.12))
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.smooth(duration: 0.15), value: configuration.isPressed)
    }
}

/// Slight shrink while pressed, for custom-drawn tappable cards.
struct PressableButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .opacity(configuration.isPressed ? 0.9 : 1)
            .animation(.smooth(duration: 0.15), value: configuration.isPressed)
    }
}

// MARK: - Icon tile

/// SF Symbol in a rounded square. `filled` uses the brand gradient with a white
/// glyph; otherwise the glyph sits on a light tint of `tint`.
struct KeepshireIconTile: View {
    let systemName: String
    var tint: Color = KeepshireTheme.accent
    var size: CGFloat = 40
    var filled = false

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: size * 0.44, weight: .semibold))
            .foregroundStyle(filled ? AnyShapeStyle(.white) : AnyShapeStyle(tint))
            .frame(width: size, height: size)
            .background(
                RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
                    .fill(filled ? AnyShapeStyle(KeepshireTheme.actionGradient) : AnyShapeStyle(tint.opacity(0.14)))
            )
            .accessibilityHidden(true)
    }
}

// MARK: - Hero header

/// Centred header: the app logo (or a symbol in a gradient tile), a rounded
/// title, and an optional subtitle.
struct KeepshireHero: View {
    enum Artwork {
        case logo
        case symbol(String)
    }

    var artwork: Artwork = .logo
    let title: String
    var subtitle: String?
    var artworkSize: CGFloat = 76

    var body: some View {
        VStack(spacing: 16) {
            artworkView
            VStack(spacing: 8) {
                Text(title)
                    .font(.system(.title, design: .rounded, weight: .bold))
                    .accessibilityAddTraits(.isHeader)
                if let subtitle {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private var artworkView: some View {
        switch artwork {
        case .logo:
            Image("AppLogo")
                .resizable()
                .frame(width: artworkSize, height: artworkSize)
                .shadow(color: KeepshireTheme.glowTeal.opacity(0.35), radius: 16, y: 8)
                .accessibilityHidden(true)
        case .symbol(let name):
            KeepshireIconTile(systemName: name, size: artworkSize, filled: true)
                .shadow(color: KeepshireTheme.glowTeal.opacity(0.35), radius: 16, y: 8)
        }
    }
}

/// Branded placeholder for empty iPad detail columns.
struct KeepshirePlaceholder: View {
    let title: String
    let message: String
    var systemName: String?

    var body: some View {
        VStack(spacing: 14) {
            if let systemName {
                KeepshireIconTile(systemName: systemName, size: 64)
            } else {
                Image("AppLogo")
                    .resizable()
                    .frame(width: 64, height: 64)
                    .opacity(0.9)
                    .accessibilityHidden(true)
            }
            Text(title)
                .font(.system(.title3, design: .rounded, weight: .semibold))
            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(KeepshireBackground())
    }
}

// MARK: - Navigation bar

enum KeepshireAppearance {
    /// Rounded navigation titles everywhere, matching the hero headings.
    static func apply() {
        let appearance = UINavigationBar.appearance()
        appearance.largeTitleTextAttributes = [.font: roundedFont(size: 34, weight: .bold)]
        appearance.titleTextAttributes = [.font: roundedFont(size: 17, weight: .semibold)]
    }

    private static func roundedFont(size: CGFloat, weight: UIFont.Weight) -> UIFont {
        let base = UIFont.systemFont(ofSize: size, weight: weight)
        guard let descriptor = base.fontDescriptor.withDesign(.rounded) else { return base }
        return UIFont(descriptor: descriptor, size: size)
    }
}

// MARK: - Text fields

extension View {
    /// Raised rounded container for a text or secure field (plus an optional
    /// trailing reveal button). Apply `.textFieldStyle(.plain)` to the field.
    func keepshireFieldStyle() -> some View {
        self
            .padding(.horizontal, 16)
            .frame(minHeight: 52)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color(.secondarySystemGroupedBackground))
                    .shadow(color: .black.opacity(0.04), radius: 5, y: 2)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Color(.separator).opacity(0.4), lineWidth: 0.5)
            )
    }
}

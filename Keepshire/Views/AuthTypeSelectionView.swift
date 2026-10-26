//
//  AuthTypeSelectionView.swift
//  Keepshire
//
//  Created on 10/07/25.
//

import SwiftUI

struct AuthTypeSelectionView: View {
    let onAuthTypeSelected: (AuthenticationType) -> Void
    @State private var selectedType: AuthenticationType = .passcode6
    @State private var navigationPath = NavigationPath()
    
    /// Shared by the hero, cards, and Continue so their edges line up; capped for iPad.
    private static let contentWidth: CGFloat = 520
    private static let horizontalMargin: CGFloat = 20

    var body: some View {
        NavigationStack(path: $navigationPath) {
            GeometryReader { proxy in
                ScrollView {
                    VStack(spacing: 32) {
                        heroSection
                        selectionCards
                    }
                    .padding(.horizontal, Self.horizontalMargin)
                    .padding(.top, 24)
                    .padding(.bottom, 40)
                    .frame(maxWidth: Self.contentWidth)
                    // Centred in the space above the footer; scrolls when text is large.
                    .frame(maxWidth: .infinity, minHeight: proxy.size.height)
                }
                .scrollBounceBehavior(.basedOnSize)
            }
            .background(background)
            .safeAreaInset(edge: .bottom) { footer }
            .navigationTitle("Security Setup")
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: AuthenticationType.self) { authType in
                if authType.isPasscode {
                    PasscodeSetupView(authType: authType, onPasscodeSet: {
                        onAuthTypeSelected(authType)
                    }, onCancel: {
                        navigationPath.removeLast()
                    })
                } else {
                    PasswordSetupView(onPasswordSet: {
                        onAuthTypeSelected(authType)
                    }, onCancel: {
                        navigationPath.removeLast()
                    })
                }
            }
        }
    }
    
    // MARK: - View Components

    /// Grouped background with a soft brand tint across the top.
    private var background: some View {
        ZStack(alignment: .top) {
            Color(.systemGroupedBackground)
            LinearGradient(
                colors: [KeepshireTheme.glowTeal.opacity(0.18), KeepshireTheme.glowGreen.opacity(0.06), .clear],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 420)
        }
        .ignoresSafeArea()
    }
    
    private var heroSection: some View {
        VStack(spacing: 18) {
            Image("AppLogo")
                .resizable()
                .frame(width: 84, height: 84)
                .shadow(color: KeepshireTheme.glowTeal.opacity(0.35), radius: 18, y: 8)
                .accessibilityHidden(true)

            VStack(spacing: 8) {
                Text("Secure your vault")
                    .font(.system(.largeTitle, design: .rounded, weight: .bold))
                    .accessibilityAddTraits(.isHeader)
                Text("Choose how you'll unlock Keepshire. You can change it later in Settings.")
                    .font(.body)
                    .foregroundColor(.secondary)
            }
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
    }
    
    private var selectionCards: some View {
        VStack(spacing: 12) {
            ForEach(AuthenticationType.allCases, id: \.self) { type in
                AuthTypeCard(
                    type: type,
                    isSelected: selectedType == type,
                    onTap: {
                        withAnimation(.smooth(duration: 0.25)) { selectedType = type }
                    }
                )
            }
        }
    }

    private var footer: some View {
        VStack(spacing: 14) {
            continueButton

            (Text(Image(systemName: "exclamationmark.shield.fill")).foregroundColor(.orange)
                + Text("  If you forget your passcode or password, Keepshire cannot recover your files."))
                .font(.footnote)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("auth.noRecoveryWarning")
        }
        .padding(.horizontal, Self.horizontalMargin)
        .padding(.top, 16)
        .padding(.bottom, 8)
        .frame(maxWidth: Self.contentWidth)
        .frame(maxWidth: .infinity)
        .background(
            // Fades the cards out under the pinned footer instead of a hard edge.
            LinearGradient(
                colors: [Color(.systemGroupedBackground).opacity(0), Color(.systemGroupedBackground)],
                startPoint: .top,
                endPoint: .init(x: 0.5, y: 0.25)
            )
            .ignoresSafeArea()
        )
    }
    
    private var continueButton: some View {
        Button(action: { 
            navigationPath.append(selectedType)
        }) {
            HStack(spacing: 8) {
                Text("Continue")
                    .font(.system(.headline, design: .rounded))
                Image(systemName: "arrow.right")
                    .font(.system(size: 16, weight: .semibold))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(KeepshireTheme.actionGradient)
            )
            .shadow(color: KeepshireTheme.glowTeal.opacity(0.3), radius: 12, y: 6)
        }
        .buttonStyle(PressableButtonStyle())
        .accessibilityIdentifier("auth.continue")
        .accessibilityLabel("Continue with \(selectedType.displayName)")
    }
}

/// Slight shrink while pressed, so custom-drawn buttons still feel tappable.
private struct PressableButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .opacity(configuration.isPressed ? 0.9 : 1)
            .animation(.smooth(duration: 0.15), value: configuration.isPressed)
    }
}

struct AuthTypeCard: View {
    let type: AuthenticationType
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                iconView
                
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 8) {
                        Text(type.displayName)
                            .font(.system(.headline, design: .rounded))
                            .foregroundColor(.primary)
                        if type == .passcode6 {
                            recommendedBadge
                        }
                    }
                    
                    Text(descriptionText)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.leading)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                selectionIndicator
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color(.secondarySystemGroupedBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(KeepshireTheme.accent.opacity(isSelected ? 0.06 : 0))
                    )
                    .shadow(color: .black.opacity(isSelected ? 0.08 : 0.04), radius: isSelected ? 12 : 6, y: 3)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(isSelected ? KeepshireTheme.accent : Color(.separator).opacity(0.4),
                                  lineWidth: isSelected ? 2 : 0.5)
            )
            .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(PressableButtonStyle())
        .accessibilityIdentifier("auth.choice.\(type.rawValue)")
        .accessibilityLabel("\(type.displayName), \(descriptionText)")
        .accessibilityValue(isSelected ? "Selected" : "Not selected")
    }
    
    /// Same-size tiles keep the title column aligned whatever the symbol's width.
    /// The selected tile fills with the brand gradient.
    private var iconView: some View {
        Image(systemName: iconName)
            .font(.system(size: 19, weight: .semibold))
            .foregroundStyle(isSelected ? AnyShapeStyle(.white) : AnyShapeStyle(KeepshireTheme.accent))
            .frame(width: 46, height: 46)
            .background(
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .fill(isSelected ? AnyShapeStyle(KeepshireTheme.actionGradient) : AnyShapeStyle(KeepshireTheme.accent.opacity(0.12)))
            )
    }

    private var recommendedBadge: some View {
        Text("Recommended")
            .font(.system(.caption2, design: .rounded, weight: .bold))
            .foregroundColor(KeepshireTheme.accent)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(Capsule().fill(KeepshireTheme.accent.opacity(0.12)))
    }
    
    private var selectionIndicator: some View {
        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
            .font(.title2)
            .foregroundColor(isSelected ? KeepshireTheme.accent : Color(.tertiaryLabel))
            .contentTransition(.symbolEffect(.replace))
    }
    
    private var iconName: String {
        switch type {
        case .passcode4:
            return "circle.grid.2x2.fill"
        case .passcode6:
            return "circle.grid.3x3.fill"
        case .password:
            return "character.cursor.ibeam"
        }
    }
    
    private var descriptionText: String {
        switch type {
        case .passcode4:
            return "Quick but weaker 4-digit PIN"
        case .passcode6:
            return "More secure 6-digit PIN"
        case .password:
            return "Custom alphanumeric password"
        }
    }
}

#Preview {
    AuthTypeSelectionView { type in
        VaultLog.debug("Selected: \(type.displayName)")
    }
} 
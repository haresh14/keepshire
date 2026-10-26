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
    
    /// Shared by the header, cards, and Continue so their edges line up; capped for iPad.
    private static let contentWidth: CGFloat = 560
    private static let horizontalMargin: CGFloat = 20

    var body: some View {
        NavigationStack(path: $navigationPath) {
            ScrollView {
                VStack(spacing: 28) {
                    headerSection
                    selectionCards
                }
                .padding(.horizontal, Self.horizontalMargin)
                .padding(.top, 8)
                .padding(.bottom, 24)
                .frame(maxWidth: Self.contentWidth)
                .frame(maxWidth: .infinity)
            }
            .scrollBounceBehavior(.basedOnSize)
            .safeAreaInset(edge: .bottom) { footer }
            .navigationTitle("Security Setup")
            .navigationBarTitleDisplayMode(.large)
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
    
    private var headerSection: some View {
        VStack(spacing: 14) {
            Image("AppLogo")
                .resizable()
                .frame(width: 72, height: 72)
                .shadow(color: .black.opacity(0.1), radius: 8, y: 4)
                .accessibilityHidden(true)

            VStack(spacing: 6) {
                Text("Lock your vault")
                    .font(.title3.weight(.semibold))
                Text("Choose how you'll unlock Keepshire. You can change this later in Settings.")
                    .font(.subheadline)
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
                        withAnimation(.snappy(duration: 0.2)) { selectedType = type }
                    }
                )
            }
        }
    }

    private var footer: some View {
        VStack(spacing: 12) {
            Text("If you forget your passcode or password, Keepshire cannot recover your files.")
                .font(.footnote)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("auth.noRecoveryWarning")

            continueButton
        }
        .padding(.horizontal, Self.horizontalMargin)
        .padding(.top, 12)
        .padding(.bottom, 8)
        .frame(maxWidth: Self.contentWidth)
        .frame(maxWidth: .infinity)
        .background(Color(.systemBackground))
    }
    
    private var continueButton: some View {
        Button(action: { 
            navigationPath.append(selectedType)
        }) {
            HStack(spacing: 8) {
                Text("Continue")
                    .font(.system(size: 17, weight: .semibold))
                Image(systemName: "arrow.right")
                    .font(.system(size: 16, weight: .semibold))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(KeepshireTheme.accent)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .accessibilityIdentifier("auth.continue")
        .flowMarker("auth.continue")
        .accessibilityLabel("Continue with \(selectedType.displayName)")
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
                    Text(type.displayName)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text(descriptionText)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.leading)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                selectionIndicator
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(.secondarySystemBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(isSelected ? KeepshireTheme.accent : Color.clear, lineWidth: 2)
            )
            .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(PlainButtonStyle())
        .accessibilityIdentifier("auth.choice.\(type.rawValue)")
        .flowMarker("auth.choice.\(type.rawValue)")
        .accessibilityLabel("\(type.displayName), \(descriptionText)")
        .accessibilityValue(isSelected ? "Selected" : "Not selected")
    }
    
    /// Same-size tiles keep the title column aligned whatever the symbol's width.
    private var iconView: some View {
        Image(systemName: iconName)
            .font(.system(size: 20, weight: .semibold))
            .foregroundColor(KeepshireTheme.accent)
            .frame(width: 44, height: 44)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(KeepshireTheme.accent.opacity(0.12))
            )
    }
    
    private var selectionIndicator: some View {
        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
            .font(.title2)
            .foregroundColor(isSelected ? KeepshireTheme.accent : Color(.tertiaryLabel))
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
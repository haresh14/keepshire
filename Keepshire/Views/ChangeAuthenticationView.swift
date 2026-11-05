//
//  ChangeAuthenticationView.swift
//  Keepshire
//
//  Created on 10/07/25.
//

import SwiftUI

struct ChangeAuthenticationView: View {
    let currentAuthType: AuthenticationType
    let onAuthChanged: () -> Void
    
    @Environment(\.dismiss) var dismiss
    @State private var currentPassword: String = ""
    @State private var newAuthType: AuthenticationType = .passcode4
    @State private var showCurrentPassword: Bool = false
    @State private var isCurrentPasswordVerified: Bool = false
    @State private var showError: Bool = false
    @State private var errorMessage: String = ""
    @State private var navigationPath = NavigationPath()
    /// The stored credential the vault key is derived from; the typed text may differ in whitespace.
    @State private var verifiedOldPassword: String = ""
    @FocusState private var isCurrentPasswordFocused: Bool
    
    var body: some View {
        NavigationStack(path: $navigationPath) {
            GeometryReader { proxy in
                ScrollView {
                    VStack(spacing: 30) {
                        if !isCurrentPasswordVerified {
                            currentPasswordSection
                        } else {
                            newAuthSelectionSection
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 16)
                    .frame(maxWidth: 520)
                    // Centred when it fits; scrolls on small screens or large text.
                    .frame(maxWidth: .infinity, minHeight: proxy.size.height)
                }
                .scrollBounceBehavior(.basedOnSize)
            }
            .background(KeepshireBackground())
            .navigationTitle("Change Authentication")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { dismiss() }) {
                        Text("Cancel")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(KeepshireTheme.accent)
                    }
                }
            }
            .navigationDestination(for: AuthenticationType.self) { authType in
                if authType.isPasscode {
                    PasscodeSetupView(
                        authType: authType,
                        onPasscodeSet: finishCredentialChange,
                        onCancel: { navigationPath.removeLast() },
                        saveCredential: { try commitCredential($0, authType: authType) }
                    )
                } else {
                    PasswordSetupView(
                        onPasswordSet: finishCredentialChange,
                        onCancel: { navigationPath.removeLast() },
                        saveCredential: { try commitCredential($0, authType: .password) }
                    )
                }
            }
        }
    }
    
    // MARK: - View Components
    
    private var currentPasswordSection: some View {
        VStack(spacing: 20) {
            headerSection
            currentPasswordInput
            errorView
        }
    }
    
    private var headerSection: some View {
        KeepshireHero(
            artwork: .symbol("lock.shield.fill"),
            title: "Verify it's you",
            subtitle: "Enter your current \(currentAuthType.isPasscode ? "passcode" : "password") to continue",
            artworkSize: 64
        )
    }
    
    private var currentPasswordInput: some View {
        VStack(spacing: 12) {
            if currentAuthType.isPasscode, let digitCount = currentAuthType.digitCount {
                // OTP-style input for passcodes
                OTPStylePasscodeView(digitCount: digitCount, passcode: $currentPassword)
            } else {
                // Password input
                HStack {
                    Group {
                        if showCurrentPassword {
                            TextField("Current Password", text: $currentPassword)
                        } else {
                            SecureField("Current Password", text: $currentPassword)
                        }
                    }
                    .textFieldStyle(.plain)
                    .focused($isCurrentPasswordFocused)
                    .onSubmit {
                        verifyCurrentPassword()
                    }
                    
                    Button(action: { showCurrentPassword.toggle() }) {
                        Image(systemName: showCurrentPassword ? "eye.slash" : "eye")
                            .foregroundColor(.secondary)
                    }
                }
                .keepshireFieldStyle()
            }
        }
        .onAppear {
            if !currentAuthType.isPasscode {
                isCurrentPasswordFocused = true
            }
        }
        .onChange(of: currentPassword) { _, newValue in
            // Auto-verify for passcodes when complete
            if currentAuthType.isPasscode, let digitCount = currentAuthType.digitCount {
                if newValue.count == digitCount {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        verifyCurrentPassword()
                    }
                }
            }
            // For passwords, verification happens on submit (Enter key)
        }
    }
    

    
    private var newAuthSelectionSection: some View {
        VStack(spacing: 20) {
            newAuthHeaderSection
            authTypeSelection
            proceedButton
        }
    }
    
    private var newAuthHeaderSection: some View {
        KeepshireHero(
            artwork: .symbol("checkmark.shield.fill"),
            title: "Choose a new lock",
            subtitle: "Your files stay as they are; only the lock that opens them changes.",
            artworkSize: 64
        )
    }
    
    private var authTypeSelection: some View {
        VStack(spacing: 12) {
            ForEach(AuthenticationType.allCases, id: \.self) { type in
                AuthTypeCard(
                    type: type,
                    isSelected: newAuthType == type,
                    onTap: { withAnimation(.smooth(duration: 0.25)) { newAuthType = type } }
                )
            }
            
            if newAuthType == currentAuthType {
                Text("You are changing to the same authentication type")
                    .font(.caption)
                    .foregroundColor(.orange)
            }
        }
    }
    
    private var proceedButton: some View {
        Button(action: proceedToNewAuth) {
            Label("Set New Authentication", systemImage: "key.fill")
        }
        .buttonStyle(KeepshirePrimaryButtonStyle())
    }
    
    @ViewBuilder
    private var errorView: some View {
        if showError {
            Text(errorMessage)
                .foregroundColor(.red)
                .font(.caption)
                .transition(.opacity)
        }
    }
    
    // MARK: - Actions
    
    private func verifyCurrentPassword() {
        let throttle = UnlockThrottle.shared
        if let remaining = throttle.remainingLockout() {
            showError(message: UnlockThrottle.message(for: remaining))
            currentPassword = ""
            return
        }

        // Setup stores passwords trimmed, so a stray space typed here still matches.
        let candidates = [currentPassword, currentPassword.trimmingCharacters(in: .whitespacesAndNewlines)]
        if let match = candidates.first(where: { FileStorageManager.shared.verifyCredential($0) }) {
            throttle.recordSuccess()
            verifiedOldPassword = match
            withAnimation(.easeInOut(duration: 0.3)) {
                isCurrentPasswordVerified = true
            }
            return
        }

        let type = currentAuthType.isPasscode ? "passcode" : "password"
        if let wait = throttle.recordFailure() {
            showError(message: UnlockThrottle.message(for: wait))
        } else {
            showError(message: "Incorrect \(type)")
        }
        currentPassword = ""
    }
    
    private func proceedToNewAuth() {
        // Navigate to setup view using native navigation
        navigationPath.append(newAuthType)
    }
    
    private func showError(message: String) {
        errorMessage = message
        showError = true
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            showError = false
        }
    }
    
    // MARK: - Credential Change

    /// Files are sealed with a vault key that never changes; this only re-wraps that key. The new
    /// wrap and its type replace the old ones in one Keychain write, so no failure can leave a
    /// credential that does not open the vault or a keypad that cannot enter it.
    private func commitCredential(_ newPassword: String, authType: AuthenticationType) throws {
        try FileStorageManager.shared.changeCredential(from: verifiedOldPassword, to: newPassword, authType: authType)
        KeychainManager.shared.setAuthenticationType(authType)
    }

    private func finishCredentialChange() {
        navigationPath = NavigationPath()
        onAuthChanged()
        dismiss()
    }
}

#Preview {
    ChangeAuthenticationView(
        currentAuthType: .passcode4,
        onAuthChanged: { VaultLog.debug("Auth changed") }
    )
} 
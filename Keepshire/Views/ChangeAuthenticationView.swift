//
//  ChangeAuthenticationView.swift
//  Keepshire
//
//  Created on 10/07/25.
//

import SwiftUI

struct ChangeAuthenticationView: View {
    let currentAuthType: AuthenticationType
    /// The lock screen's "Forgot passcode?": the recovery key stands in for the current credential.
    var isRecovering = false
    let onAuthChanged: () -> Void
    
    @Environment(\.dismiss) var dismiss
    @State private var currentPassword: String = ""
    @State private var newAuthType: AuthenticationType = .passcode4
    @State private var showCurrentPassword: Bool = false
    @State private var isCurrentPasswordVerified: Bool = false
    @State private var feedback = CredentialFeedbackState()
    @State private var navigationPath = NavigationPath()
    /// The stored credential the vault key is derived from; the typed text may differ in whitespace.
    @State private var verifiedOldPassword: String = ""
    @State private var verifiedRecoveryKey: RecoveryKey?
    @FocusState private var isCurrentPasswordFocused: Bool
    
    var body: some View {
        NavigationStack(path: $navigationPath) {
            GeometryReader { proxy in
                ScrollView {
                    VStack(spacing: 30) {
                        if !isCurrentPasswordVerified {
                            if isRecovering {
                                recoveryKeySection
                            } else {
                                currentPasswordSection
                            }
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
            .navigationTitle(isRecovering ? "Recover Vault" : "Change Authentication")
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
                .shake(feedback.shakes)
                .onChange(of: currentPassword) { _, value in
                    if !value.isEmpty && !feedback.isLocked { feedback.clear() }
                }
                .disabled(feedback.isLocked)
                .opacity(feedback.isLocked ? 0.45 : 1)
                .animation(.easeOut(duration: 0.2), value: feedback.isLocked)
            errorView
        }
    }
    
    private var recoveryKeySection: some View {
        VStack(spacing: 20) {
            KeepshireHero(
                artwork: .symbol("key.horizontal.fill"),
                title: "Enter your recovery key",
                subtitle: "Use the key you saved when you turned on recovery. You'll then choose a new \(currentAuthType.isPasscode ? "passcode" : "password").",
                artworkSize: 64
            )
            TextField("XXXX-XXXX-XXXX-XXXX-XXXX-XXXX", text: $currentPassword, axis: .vertical)
                .textFieldStyle(.plain)
                .font(.system(.body, design: .monospaced, weight: .semibold))
                .multilineTextAlignment(.center)
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
                .focused($isCurrentPasswordFocused)
                .onSubmit(verifyRecoveryKey)
                .keepshireFieldStyle()
                .shake(feedback.shakes)
                .onChange(of: currentPassword) { _, value in
                    if !value.isEmpty && !feedback.isLocked { feedback.clear() }
                }
                .disabled(feedback.isLocked)
                .opacity(feedback.isLocked ? 0.45 : 1)
                .accessibilityIdentifier("recover.recoveryKey")
            errorView
            Button("Continue", action: verifyRecoveryKey)
                .buttonStyle(KeepshirePrimaryButtonStyle())
                .disabled(currentPassword.isEmpty || feedback.isLocked)
        }
        .onAppear {
            isCurrentPasswordFocused = true
            if let until = UnlockThrottle.shared.lockedUntil() {
                showLockout(until: until)
            }
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
            if let until = UnlockThrottle.shared.lockedUntil() {
                showLockout(until: until)
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
            
            if newAuthType == currentAuthType && !isRecovering {
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
    
    private var errorView: some View {
        CredentialFeedback(message: feedback.message, lockedUntil: feedback.lockedUntil)
    }
    
    // MARK: - Actions
    
    private func verifyCurrentPassword() {
        let throttle = UnlockThrottle.shared
        if let until = throttle.lockedUntil() {
            showLockout(until: until)
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

        let rejection = throttle.rejection(noun: currentAuthType.isPasscode ? "passcode" : "password")
        showError(message: rejection.message, lockedUntil: rejection.lockedUntil)
        currentPassword = ""
    }
    
    /// Counts against the same throttle as the passcode, so the recovery key is no side door for
    /// guessing. A malformed key is a typo, not a guess, and costs nothing.
    private func verifyRecoveryKey() {
        let throttle = UnlockThrottle.shared
        if let until = throttle.lockedUntil() {
            showLockout(until: until)
            return
        }
        guard let recoveryKey = RecoveryKey(typed: currentPassword) else {
            let id = feedback.reject("A recovery key has \(RecoveryKey.characterCount) letters and numbers.")
            clearFeedback(id, after: 4)
            return
        }
        guard FileStorageManager.shared.verifyRecoveryKey(recoveryKey) else {
            let rejection = throttle.rejection(noun: "recovery key")
            showError(message: rejection.message, lockedUntil: rejection.lockedUntil)
            return
        }
        verifiedRecoveryKey = recoveryKey
        newAuthType = currentAuthType
        withAnimation(.easeInOut(duration: 0.3)) {
            isCurrentPasswordVerified = true
        }
    }

    private func proceedToNewAuth() {
        // Navigate to setup view using native navigation
        navigationPath.append(newAuthType)
    }
    
    /// Stays until the next keypress, or until a lockout ends, so it cannot vanish unread.
    private func showError(message: String, lockedUntil: Date? = nil) {
        let id = feedback.reject(message, lockedUntil: lockedUntil)
        if let lockedUntil {
            clearFeedback(id, after: lockedUntil.timeIntervalSinceNow)
        }
    }

    private func showLockout(until lockedUntil: Date) {
        let id = feedback.showLockout(until: lockedUntil)
        clearFeedback(id, after: lockedUntil.timeIntervalSinceNow)
    }

    private func clearFeedback(_ id: UUID, after delay: TimeInterval) {
        DispatchQueue.main.asyncAfter(deadline: .now() + max(0, delay)) {
            feedback.clear(ifStill: id)
        }
    }
    
    // MARK: - Credential Change

    /// Files are sealed with a vault key that never changes; this only re-wraps that key. The new
    /// wrap and its type replace the old ones in one Keychain write, so no failure can leave a
    /// credential that does not open the vault or a keypad that cannot enter it.
    private func commitCredential(_ newPassword: String, authType: AuthenticationType) throws {
        if let verifiedRecoveryKey {
            try FileStorageManager.shared.resetCredential(withRecoveryKey: verifiedRecoveryKey, to: newPassword, authType: authType)
            KeychainManager.shared.setAuthenticationType(authType)
            removeFakePasswordIfUnusable(newPassword: newPassword, authType: authType)
            return
        }
        try FileStorageManager.shared.changeCredential(from: verifiedOldPassword, to: newPassword, authType: authType)
        KeychainManager.shared.setAuthenticationType(authType)
    }

    /// A decoy of another lock type cannot be typed any more, and one equal to the new credential
    /// would never be reached, since the real vault is tried first.
    private func removeFakePasswordIfUnusable(newPassword: String, authType: AuthenticationType) {
        let keychain = KeychainManager.shared
        guard keychain.isFakePasswordSet(),
              authType != currentAuthType || keychain.verifyFakePassword(newPassword) else { return }
        try? keychain.deleteFakePassword()
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
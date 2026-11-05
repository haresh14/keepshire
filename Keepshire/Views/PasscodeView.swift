//
//  PasscodeView.swift
//  Keepshire
//
//  Created on 10/07/25.
//

import SwiftUI

struct PasscodeView: View {
    @State private var passcode: String = ""
    @State private var confirmPasscode: String = ""
    @State private var feedback = CredentialFeedbackState()
    @State private var showPassword: Bool = false
    @State private var hasRecoveryKey = false
    @State private var isRecovering = false
    @FocusState private var isPasscodeFocused: Bool
    
    let isSettingPasscode: Bool
    let onAuthenticated: () -> Void
    let onCancel: (() -> Void)?
    
    private var authType: AuthenticationType {
        KeychainManager.shared.getAuthenticationType()
    }
    
    private var isPasswordType: Bool {
        authType == .password
    }
    
    private var digitCount: Int? {
        authType.digitCount
    }
    
    init(isSettingPasscode: Bool = false, onAuthenticated: @escaping () -> Void, onCancel: (() -> Void)? = nil) {
        self.isSettingPasscode = isSettingPasscode
        self.onAuthenticated = onAuthenticated
        self.onCancel = onCancel
    }
    
    var body: some View {
        ZStack {
            KeepshireBackground()
            
            GeometryReader { proxy in
                ScrollView {
                    VStack(spacing: 32) {
                        header
                        
                        VStack(spacing: 18) {
                            passcodeFields
                                .shake(feedback.shakes)
                                .onChange(of: passcode) { _, value in
                                    if !value.isEmpty && !feedback.isLocked { feedback.clear() }
                                }
                                // The keypad dims its own digit keys so its Face ID key stays usable.
                                .disabled(isPasswordType && feedback.isLocked)
                                .opacity(isPasswordType && feedback.isLocked ? 0.45 : 1)
                                .animation(.easeOut(duration: 0.2), value: feedback.isLocked)
                            errorView
                            if isSettingPasscode {
                                actionButton
                            }
                            forgotButton
                            cancelButton
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 24)
                    .frame(maxWidth: 440)
                    // Centred when it fits; scrolls on small screens or large text.
                    .frame(maxWidth: .infinity, minHeight: proxy.size.height)
                }
                .scrollBounceBehavior(.basedOnSize)
            }
            .safeAreaInset(edge: .bottom) {
                biometricButton
            }
        }
        .onAppear(perform: handleOnAppear)
        .sheet(isPresented: $isRecovering) {
            ChangeAuthenticationView(currentAuthType: authType, isRecovering: true, onAuthChanged: finishRecovery)
                .presentationSizing(.form)
        }
    }
    
    // MARK: - View Components
    
    @ViewBuilder
    private var header: some View {
        if isSettingPasscode {
            KeepshireHero(
                artwork: .symbol("lock.fill"),
                title: isPasswordType ? "Set Your Password" : "Set Your Passcode",
                subtitle: isPasswordType ? "Create a secure password to protect your vault" : "Create a secure passcode to protect your vault",
                artworkSize: 64
            )
        } else {
            KeepshireHero(
                title: "Welcome back",
                subtitle: isPasswordType ? "Enter your password to open your vault" : "Enter your passcode to open your vault",
                artworkSize: 72
            )
        }
    }
    
    @ViewBuilder
    private var passcodeFields: some View {
        if isPasswordType {
            // Password input fields
            HStack {
                Group {
                    if showPassword {
                        TextField(isSettingPasscode ? "Password" : "Enter Password", text: $passcode)
                    } else {
                        SecureField(isSettingPasscode ? "Password" : "Enter Password", text: $passcode)
                    }
                }
                .textFieldStyle(.plain)
                .focused($isPasscodeFocused)
                .onSubmit(handlePasscodeSubmit)
                
                Button(action: { showPassword.toggle() }) {
                    Image(systemName: showPassword ? "eye.slash" : "eye")
                        .foregroundColor(.secondary)
                }
            }
            .keepshireFieldStyle()
            
            if isSettingPasscode {
                HStack {
                    Group {
                        if showPassword {
                            TextField("Confirm Password", text: $confirmPasscode)
                        } else {
                            SecureField("Confirm Password", text: $confirmPasscode)
                        }
                    }
                    .textFieldStyle(.plain)
                    .onSubmit(handleSetPasscode)
                    
                    Button(action: { showPassword.toggle() }) {
                        Image(systemName: showPassword ? "eye.slash" : "eye")
                            .foregroundColor(.secondary)
                    }
                }
                .keepshireFieldStyle()
            }
        } else if let digitCount = digitCount {
            // OTP-style passcode input
            if isSettingPasscode {
                VStack(spacing: 20) {
                    OTPStylePasscodeView(digitCount: digitCount, passcode: $passcode)
                    
                    if !passcode.isEmpty && passcode.count == digitCount {
                        VStack(spacing: 16) {
                            OTPStylePasscodeView(digitCount: digitCount, passcode: $confirmPasscode)
                        }
                    }
                }
            } else {
                VStack(spacing: 16) {
                    OTPStylePasscodeView(
                        digitCount: digitCount,
                        passcode: $passcode,
                        biometricKey: shouldShowBiometric ? BiometricKey(
                            systemImage: biometricIconName,
                            label: "Unlock with \(biometricDisplayName)",
                            action: authenticateWithBiometrics
                        ) : nil,
                        keysDisabled: feedback.isLocked
                    )
                        .onChange(of: passcode) { _, newValue in
                            // Auto-login when passcode is complete
                            if newValue.count == digitCount {
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                    handleAuthentication()
                                }
                            }
                        }
                }
            }
        } else {
            // Fallback to traditional input
            SecureField(isPasswordType ? "Password" : "Passcode", text: $passcode)
                .textFieldStyle(.plain)
                .keepshireFieldStyle()
                .focused($isPasscodeFocused)
                .onSubmit(handlePasscodeSubmit)
            
            if isSettingPasscode {
                SecureField(isPasswordType ? "Confirm Password" : "Confirm Passcode", text: $confirmPasscode)
                    .textFieldStyle(.plain)
                    .keepshireFieldStyle()
                    .onSubmit(handleSetPasscode)
            }
        }
    }
    
    private var errorView: some View {
        CredentialFeedback(message: feedback.message, lockedUntil: feedback.lockedUntil)
    }
    
    @ViewBuilder
    private var actionButton: some View {
        if isSettingPasscode {
            Button(action: handleButtonAction) {
                Text(isPasswordType ? "Set Password" : "Set Passcode")
            }
            .buttonStyle(KeepshirePrimaryButtonStyle())
            .disabled(isButtonDisabled)
        }
    }
    
    @ViewBuilder
    private var cancelButton: some View {
        if let onCancel = onCancel {
            Button("Cancel", action: onCancel)
                .font(.system(.body, design: .rounded, weight: .medium))
                .foregroundColor(KeepshireTheme.accent)
        }
    }
    
    @ViewBuilder
    private var forgotButton: some View {
        if !isSettingPasscode && hasRecoveryKey {
            Button(isPasswordType ? "Forgot password?" : "Forgot passcode?") { isRecovering = true }
                .font(.system(.subheadline, design: .rounded, weight: .medium))
                .foregroundColor(KeepshireTheme.accent)
                .accessibilityIdentifier("lock.forgot")
        }
    }

    /// Passcodes get Face ID as a key in the keypad; a password has no keypad, so it keeps this button.
    @ViewBuilder
    private var biometricButton: some View {
        if shouldShowBiometric && isPasswordType {
            Button(action: authenticateWithBiometrics) {
                Label("Use \(biometricDisplayName)", systemImage: biometricIconName)
            }
            .buttonStyle(KeepshireSecondaryButtonStyle())
            .frame(maxWidth: 280)
            .padding(.bottom, 16)
        }
    }
    
    // MARK: - Computed Properties
    
    private var isButtonDisabled: Bool {
        passcode.isEmpty || (isSettingPasscode && confirmPasscode.isEmpty)
    }
    
    private var shouldShowBiometric: Bool {
        !isSettingPasscode && 
        KeychainManager.shared.isBiometricEnabled() &&
        BiometricAuthManager.shared.canUseBiometrics() &&
        FileStorageManager.shared.hasBiometricUnlock
    }
    
    private var biometricIconName: String {
        BiometricAuthManager.shared.biometricType() == .faceID ? "faceid" : "touchid"
    }
    
    private var biometricDisplayName: String {
        BiometricAuthManager.shared.biometricType() == .faceID ? "Face ID" : "Touch ID"
    }
    
    // MARK: - Actions
    
    private func handleOnAppear() {
        isPasscodeFocused = true
        hasRecoveryKey = !isSettingPasscode && FileStorageManager.shared.hasRecoveryKey
        // A lockout survives relaunch, so show the countdown before the first keypress is wasted.
        if !isSettingPasscode, let until = UnlockThrottle.shared.lockedUntil() {
            showLockout(until: until)
        }
        
        // Removed automatic biometric trigger - now handled by ContentView
        // to prevent UI jerking and duplicate prompts
    }
    
    private func handlePasscodeSubmit() {
        if isSettingPasscode && !confirmPasscode.isEmpty {
            handleSetPasscode()
        } else if !isSettingPasscode {
            handleAuthentication()
        }
    }
    
    private func handleButtonAction() {
        if isSettingPasscode {
            handleSetPasscode()
        } else {
            handleAuthentication()
        }
    }
    
    private func handleSetPasscode() {
        let minLength = isPasswordType ? 6 : (digitCount ?? 4)
        
        guard passcode.count >= minLength else {
            let type = isPasswordType ? "Password" : "Passcode"
            showError(message: "\(type) must be at least \(minLength) characters")
            return
        }
        
        // For passcodes, validate digit count exactly
        if let digitCount = digitCount {
            guard passcode.count == digitCount && passcode.allSatisfy({ $0.isNumber }) else {
                showError(message: "Passcode must be exactly \(digitCount) digits")
                return
            }
        }
        
        guard passcode == confirmPasscode else {
            let type = isPasswordType ? "Passwords" : "Passcodes"
            showError(message: "\(type) don't match")
            return
        }
        
        do {
            try FileStorageManager.shared.createVault(password: passcode, authType: authType)
            onAuthenticated()
        } catch {
            VaultLog.debug("ERROR: Failed to save password/passcode: \(error)")
            let type = isPasswordType ? "password" : "passcode"
            showError(message: "Failed to save \(type)")
        }
    }
    
    private func handleAuthentication() {
        let throttle = UnlockThrottle.shared
        if let until = throttle.lockedUntil() {
            showLockout(until: until)
            passcode = ""
            return
        }

        // Opening the vault key is the check: no stored copy of the passcode exists to compare against.
        // The decoy never unlocks the real key, so its session cannot read the real files.
        let isFakeLogin: Bool
        if FileStorageManager.shared.unlock(password: passcode) {
            isFakeLogin = false
        } else if KeychainManager.shared.verifyFakePassword(passcode) {
            isFakeLogin = true
        } else {
            let rejection = throttle.rejection(noun: isPasswordType ? "password" : "passcode")
            showError(message: rejection.message, lockedUntil: rejection.lockedUntil)
            passcode = ""
            return
        }

        KeychainManager.shared.clearLastBackgroundTime()
        LoginStateManager.shared.setLoginState(isFakeLogin: isFakeLogin)
        onAuthenticated()
    }
    
    /// The recovery flow has set the new credential and unlocked the real vault.
    private func finishRecovery() {
        KeychainManager.shared.clearLastBackgroundTime()
        LoginStateManager.shared.setLoginState(isFakeLogin: false)
        onAuthenticated()
    }

    private func authenticateWithBiometrics() {
        FileStorageManager.shared.unlockWithBiometrics(prompt: "Unlock your vault") { success in
            guard success else { return }
            KeychainManager.shared.clearLastBackgroundTime()
            // Biometric authentication is always real login (not fake)
            LoginStateManager.shared.setLoginState(isFakeLogin: false)
            onAuthenticated()
        }
    }
    
    /// A wrong-credential message stays until the next keypress, so it cannot vanish unread.
    /// Setup messages ("don't match") still clear on their own.
    private func showError(message: String, lockedUntil: Date? = nil) {
        let id = feedback.reject(message, lockedUntil: lockedUntil)
        if let lockedUntil {
            clearFeedback(id, after: lockedUntil.timeIntervalSinceNow)
        } else if isSettingPasscode {
            clearFeedback(id, after: 3)
        }
    }

    private func showLockout(until lockedUntil: Date) {
        let id = feedback.showLockout(until: lockedUntil)
        clearFeedback(id, after: lockedUntil.timeIntervalSinceNow)
    }

    private func clearFeedback(_ id: UUID, after delay: TimeInterval) {
        DispatchQueue.main.asyncAfter(deadline: .now() + max(0, delay)) {
            feedback.clear(ifStill: id)
            if !feedback.isLocked { isPasscodeFocused = true }
        }
    }

} 
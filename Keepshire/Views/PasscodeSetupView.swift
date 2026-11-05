//
//  PasscodeSetupView.swift
//  Keepshire
//
//  Created on 10/07/25.
//

import SwiftUI

struct PasscodeSetupView: View {
    let authType: AuthenticationType
    let onPasscodeSet: () -> Void
    let onCancel: (() -> Void)?
    let isFakePasswordSetup: Bool
    /// Replaces the plain Keychain write when the credential guards an existing vault key.
    let saveCredential: ((String) throws -> Void)?
    
    init(
        authType: AuthenticationType,
        onPasscodeSet: @escaping () -> Void,
        onCancel: (() -> Void)? = nil,
        isFakePasswordSetup: Bool = false,
        saveCredential: ((String) throws -> Void)? = nil
    ) {
        self.authType = authType
        self.onPasscodeSet = onPasscodeSet
        self.onCancel = onCancel
        self.isFakePasswordSetup = isFakePasswordSetup
        self.saveCredential = saveCredential
    }
    
    @State private var passcode: String = ""
    @State private var confirmPasscode: String = ""
    @State private var feedback = CredentialFeedbackState()
    @State private var isConfirming: Bool = false
    @Environment(\.dismiss) private var dismiss
    
    private var digitCount: Int {
        authType.digitCount ?? 4
    }
    
    private var isPasscodeValid: Bool {
        passcode.count == digitCount && passcode.allSatisfy { $0.isNumber }
    }
    
    private var isConfirmPasscodeValid: Bool {
        confirmPasscode.count == digitCount && confirmPasscode.allSatisfy { $0.isNumber }
    }
    
    var body: some View {
        GeometryReader { proxy in
            ScrollView {
                VStack(spacing: 32) {
                    headerSection
                    passcodeInputSection
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 16)
                .frame(maxWidth: 440)
                // Centred when it fits; scrolls on small screens or large text.
                .frame(maxWidth: .infinity, minHeight: proxy.size.height)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .background(KeepshireBackground())
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                if isConfirming {
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            isConfirming = false
                            confirmPasscode = ""
                            feedback.clear()
                        }
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                            Text("Back")
                        }
                    }
                } else {
                    Button(action: {
                        if let onCancel = onCancel {
                            onCancel()
                        } else {
                            dismiss()
                        }
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                            Text("Security Setup")
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - View Components
    
    private var headerSection: some View {
        VStack(spacing: 12) {
            KeepshireHero(
                artwork: .symbol(isFakePasswordSetup ? "theatermasks.fill" : (isConfirming ? "checkmark.shield.fill" : "lock.fill")),
                title: isConfirming ? "Confirm passcode" : (isFakePasswordSetup ? "Fake passcode" : "Create passcode"),
                subtitle: isConfirming ?
                    "Re-enter your \(digitCount)-digit \(isFakePasswordSetup ? "fake " : "")passcode" :
                    "Create a \(digitCount)-digit \(isFakePasswordSetup ? "fake " : "")passcode\(isFakePasswordSetup ? " that shows an empty vault when used" : " to protect your vault")",
                artworkSize: 64
            )
            .animation(.smooth(duration: 0.25), value: isConfirming)

            if !isFakePasswordSetup {
                Text("If you forget this passcode, only a recovery key can open your files. Keepshire cannot recover them.")
                    .font(.footnote)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .accessibilityIdentifier("passcode.noRecoveryWarning")
            }
        }
    }
    
    private var passcodeInputSection: some View {
        VStack(spacing: 20) {
            Group {
                if isConfirming {
                    OTPStylePasscodeView(digitCount: digitCount, passcode: $confirmPasscode)
                } else {
                    OTPStylePasscodeView(digitCount: digitCount, passcode: $passcode)
                }
            }
            .shake(feedback.shakes)
            
            errorView
        }
        .onChange(of: passcode) { _, newValue in
            if newValue.count == digitCount && !isConfirming {
                // Auto-advance to confirmation
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        isConfirming = true
                    }
                }
            }
        }
        .onChange(of: confirmPasscode) { _, newValue in
            if newValue.count == digitCount && isConfirming {
                // Auto-validate when complete
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    handlePasscodeConfirmation()
                }
            }
        }
    }
    
    private var errorView: some View {
        CredentialFeedback(message: feedback.message)
    }
    
    // MARK: - Actions
    
    private func handlePasscodeConfirmation() {
        guard passcode == confirmPasscode else {
            showError(message: "Passcodes don't match")
            confirmPasscode = ""
            return
        }
        
        guard isPasscodeValid else {
            showError(message: "Invalid passcode")
            return
        }
        
        if isFakePasswordSetup {
            // Save fake passcode
            do {
                // Validate fake passcode is different from main passcode
                if FileStorageManager.shared.verifyCredential(passcode) {
                    rejectFakePasscode()
                    return
                }
                
                try KeychainManager.shared.saveFakePassword(passcode)
                onPasscodeSet()
            } catch KeychainError.duplicateEntry {
                rejectFakePasscode()
            } catch {
                VaultLog.debug("ERROR: Failed to save fake passcode: \(error)")
                showError(message: "Failed to save fake passcode")
            }
        } else {
            // Save regular passcode and auth type
            do {
                if let saveCredential {
                    try saveCredential(passcode)
                } else {
                    try FileStorageManager.shared.createVault(password: passcode, authType: authType)
                    KeychainManager.shared.setAuthenticationType(authType)
                }
                onPasscodeSet()
            } catch {
                VaultLog.debug("ERROR: Failed to save passcode: \(error)")
                showError(message: "Failed to save passcode")
            }
        }
    }
    
    /// Starts over from the first entry: staying on confirm would compare every retry with nothing.
    private func rejectFakePasscode() {
        showError(message: "Fake passcode must be different from your main passcode")
        passcode = ""
        confirmPasscode = ""
        withAnimation(.easeInOut(duration: 0.3)) {
            isConfirming = false
        }
    }

    private func showError(message: String) {
        let id = feedback.reject(message)
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            feedback.clear(ifStill: id)
        }
    }
}

#Preview {
    NavigationStack {
        PasscodeSetupView(
            authType: .passcode4,
            onPasscodeSet: { VaultLog.debug("Passcode set") },
            onCancel: { VaultLog.debug("Cancelled") }
        )
    }
} 
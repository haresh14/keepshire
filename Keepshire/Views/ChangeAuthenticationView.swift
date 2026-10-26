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
    @State private var showMigrationProgress: Bool = false
    @State private var migrationProgress: Int = 0
    @State private var migrationTotal: Int = 0
    @State private var newPasswordForMigration: String = ""
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
                    PasscodeSetupView(authType: authType, onPasscodeSet: {
                        handlePasscodeChanged()
                    }, onCancel: {
                        navigationPath.removeLast()
                    })
                } else {
                    PasswordSetupView(onPasswordSet: {
                        handlePasswordChanged()
                    }, onCancel: {
                        navigationPath.removeLast()
                    })
                }
            }
            .navigationDestination(for: String.self) { destination in
                if destination == "migration" {
                    MigrationProgressView(
                        currentProgress: migrationProgress,
                        totalItems: migrationTotal,
                        onCancel: {
                            navigationPath.removeLast()
                        }
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
            subtitle: "Every file is re-encrypted with the new passcode or password.",
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
        do {
            let savedPassword = try KeychainManager.shared.getPassword()
            let cleanCurrentPassword = currentPassword.trimmingCharacters(in: .whitespacesAndNewlines)
            let cleanSavedPassword = savedPassword.trimmingCharacters(in: .whitespacesAndNewlines)
            
            if cleanCurrentPassword == cleanSavedPassword {
                withAnimation(.easeInOut(duration: 0.3)) {
                    isCurrentPasswordVerified = true
                }
            } else {
                let type = currentAuthType.isPasscode ? "passcode" : "password"
                showError(message: "Incorrect \(type)")
                currentPassword = ""
            }
        } catch {
            let type = currentAuthType.isPasscode ? "passcode" : "password"
            showError(message: "Failed to verify \(type)")
        }
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
    
    // MARK: - Migration Handlers
    
    private func handlePasscodeChanged() {
        startMigrationProcess()
    }
    
    private func handlePasswordChanged() {
        startMigrationProcess()
    }
    
    private func startMigrationProcess() {
        Task {
            do {
                // Get the new password that was just saved
                let newPassword = try KeychainManager.shared.getPassword()
                
                await MainActor.run {
                    migrationProgress = 0
                    migrationTotal = 0
                    // Navigate to migration view
                    navigationPath.append("migration")
                }
                
                // Start migration with old and new passwords
                try await FileStorageManager.shared.migrateFilesToNewEncryptionKey(
                    oldPassword: currentPassword,
                    newPassword: newPassword,
                    progress: { current, total in
                        Task { @MainActor in
                            migrationProgress = current
                            migrationTotal = total
                        }
                    }
                )
                
                // Migration completed successfully
                // Update the encryption key to the new one
                FileStorageManager.shared.setupEncryptionKey(from: newPassword)
                
                await MainActor.run {
                    // Navigate back and dismiss
                    navigationPath = NavigationPath()
                    onAuthChanged()
                    dismiss()
                }
                
            } catch {
                await MainActor.run {
                    // Navigate back to auth view and show error
                    navigationPath = NavigationPath()
                    showError(message: "Failed to update encryption: \(error.localizedDescription)")
                }
            }
        }
    }
}

#Preview {
    ChangeAuthenticationView(
        currentAuthType: .passcode4,
        onAuthChanged: { VaultLog.debug("Auth changed") }
    )
} 
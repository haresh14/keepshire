//
//  PasswordSetupView.swift
//  Keepshire
//
//  Created on 10/07/25.
//

import SwiftUI

struct PasswordSetupView: View {
    let onPasswordSet: () -> Void
    let onCancel: (() -> Void)?
    let isFakePasswordSetup: Bool
    
    init(onPasswordSet: @escaping () -> Void, onCancel: (() -> Void)? = nil, isFakePasswordSetup: Bool = false) {
        self.onPasswordSet = onPasswordSet
        self.onCancel = onCancel
        self.isFakePasswordSetup = isFakePasswordSetup
    }
    
    @State private var password: String = ""
    @State private var confirmPassword: String = ""
    @State private var showError: Bool = false
    @State private var errorMessage: String = ""
    @State private var showPassword: Bool = false
    @State private var showConfirmPassword: Bool = false
    @FocusState private var isPasswordFocused: Bool
    @FocusState private var isConfirmPasswordFocused: Bool
    @Environment(\.dismiss) private var dismiss
    
    private var isPasswordValid: Bool {
        password.count >= 6
    }
    
    private var passwordStrength: PasswordStrength {
        getPasswordStrength(password)
    }
    
    var body: some View {
        GeometryReader { proxy in
            ScrollView {
                VStack(spacing: 28) {
                    headerSection
                    passwordInputSection
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 16)
                .frame(maxWidth: 480)
                // Centred when it fits; scrolls above the keyboard and on small screens.
                .frame(maxWidth: .infinity, minHeight: proxy.size.height)
            }
            .scrollBounceBehavior(.basedOnSize)
            .scrollDismissesKeyboard(.interactively)
        }
        .background(KeepshireBackground())
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
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
    
    // MARK: - View Components
    
    private var headerSection: some View {
        VStack(spacing: 12) {
            KeepshireHero(
                artwork: .symbol(isFakePasswordSetup ? "theatermasks.fill" : "key.fill"),
                title: isFakePasswordSetup ? "Fake password" : "Create password",
                subtitle: isFakePasswordSetup ?
                    "Create a fake password that shows an empty vault when used" :
                    "Create a strong password to protect your vault",
                artworkSize: 64
            )

            if !isFakePasswordSetup {
                Text("If you forget this password, Keepshire cannot recover your files.")
                    .font(.footnote)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .accessibilityIdentifier("password.noRecoveryWarning")
            }
        }
    }
    
    private var passwordInputSection: some View {
        VStack(spacing: 20) {
            passwordField
            confirmPasswordField
            passwordStrengthIndicator
            errorView
            setPasswordButton
        }
    }
    
    private var passwordField: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Group {
                    if showPassword {
                        TextField("Password", text: $password)
                    } else {
                        SecureField("Password", text: $password)
                    }
                }
                .textFieldStyle(.plain)
                .focused($isPasswordFocused)
                .onSubmit {
                    isConfirmPasswordFocused = true
                }
                
                Button(action: { showPassword.toggle() }) {
                    Image(systemName: showPassword ? "eye.slash" : "eye")
                        .foregroundColor(.secondary)
                }
                .accessibilityLabel(showPassword ? "Hide password" : "Show password")
            }
            .keepshireFieldStyle()
            
            Text("Minimum 6 characters")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.leading, 4)
        }
    }
    
    private var confirmPasswordField: some View {
        HStack {
            Group {
                if showConfirmPassword {
                    TextField("Confirm Password", text: $confirmPassword)
                } else {
                    SecureField("Confirm Password", text: $confirmPassword)
                }
            }
            .textFieldStyle(.plain)
            .focused($isConfirmPasswordFocused)
            .onSubmit {
                handlePasswordSetup()
            }
            
            Button(action: { showConfirmPassword.toggle() }) {
                Image(systemName: showConfirmPassword ? "eye.slash" : "eye")
                    .foregroundColor(.secondary)
            }
            .accessibilityLabel(showConfirmPassword ? "Hide confirmation password" : "Show confirmation password")
        }
        .keepshireFieldStyle()
    }
    
    private var passwordStrengthIndicator: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !password.isEmpty {
                HStack {
                    Text("Password Strength:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(passwordStrength.description)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(passwordStrength.color)
                }
                
                ProgressView(value: passwordStrength.value, total: 1.0)
                    .tint(passwordStrength.color)
                    .scaleEffect(y: 0.5)
            }
        }
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
    
    private var setPasswordButton: some View {
        Button(action: handlePasswordSetup) {
            Label(isFakePasswordSetup ? "Set Fake Password" : "Set Password", systemImage: "checkmark")
        }
        .buttonStyle(KeepshirePrimaryButtonStyle())
        .disabled(!isButtonEnabled)
        .padding(.top, 4)
    }
    
    private var isButtonEnabled: Bool {
        isPasswordValid && !confirmPassword.isEmpty
    }
    
    // MARK: - Actions
    
    private func handlePasswordSetup() {
        // Trim whitespace and ensure clean strings
        let cleanPassword = password.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanConfirmPassword = confirmPassword.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard cleanPassword.count >= 6 else {
            showError(message: "Password must be at least 6 characters")
            return
        }
        
        guard cleanPassword == cleanConfirmPassword else {
            showError(message: "Passwords don't match")
            confirmPassword = ""
            return
        }
        
        // Additional validation: ensure password is not all the same character
        let uniqueCharacters = Set(cleanPassword)
        guard uniqueCharacters.count > 1 else {
            showError(message: "Password cannot be all the same character")
            password = ""
            confirmPassword = ""
            return
        }
        
        if isFakePasswordSetup {
            // Save fake password
            do {
                // Validate fake password is different from main password
                let mainPassword = try KeychainManager.shared.getPassword()
                if cleanPassword == mainPassword {
                    showError(message: "Fake password must be different from your main password")
                    password = ""
                    confirmPassword = ""
                    return
                }
                
                try KeychainManager.shared.saveFakePassword(cleanPassword)
                onPasswordSet()
            } catch KeychainError.duplicateEntry {
                showError(message: "Fake password must be different from your main password")
                password = ""
                confirmPassword = ""
            } catch {
                VaultLog.debug("ERROR: Failed to save fake password: \(error)")
                showError(message: "Failed to save fake password")
            }
        } else {
            // Save regular password and auth type
            do {
                try KeychainManager.shared.savePassword(cleanPassword)
                KeychainManager.shared.setAuthenticationType(.password)
                onPasswordSet()
            } catch {
                VaultLog.debug("ERROR: Failed to save password: \(error)")
                showError(message: "Failed to save password")
            }
        }
    }
    
    private func showError(message: String) {
        errorMessage = message
        showError = true
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            showError = false
        }
    }
    
    // MARK: - Password Strength
    
    private func getPasswordStrength(_ password: String) -> PasswordStrength {
        let length = password.count
        let hasUppercase = password.rangeOfCharacter(from: .uppercaseLetters) != nil
        let hasLowercase = password.rangeOfCharacter(from: .lowercaseLetters) != nil
        let hasNumbers = password.rangeOfCharacter(from: .decimalDigits) != nil
        let hasSpecialChars = password.rangeOfCharacter(from: CharacterSet(charactersIn: "!@#$%^&*()_+-=[]{}|;:,.<>?")) != nil
        
        var score = 0
        
        if length >= 6 { score += 1 }
        if length >= 10 { score += 1 }
        if hasUppercase { score += 1 }
        if hasLowercase { score += 1 }
        if hasNumbers { score += 1 }
        if hasSpecialChars { score += 1 }
        
        switch score {
        case 0...2: return .weak
        case 3...4: return .medium
        case 5...6: return .strong
        default: return .weak
        }
    }
}

enum PasswordStrength {
    case weak
    case medium
    case strong
    
    var description: String {
        switch self {
        case .weak: return "Weak"
        case .medium: return "Medium"
        case .strong: return "Strong"
        }
    }
    
    var color: Color {
        switch self {
        case .weak: return .red
        case .medium: return .orange
        case .strong: return KeepshireTheme.success
        }
    }
    
    var value: Double {
        switch self {
        case .weak: return 0.33
        case .medium: return 0.66
        case .strong: return 1.0
        }
    }
}

#Preview {
    NavigationStack {
        PasswordSetupView(
            onPasswordSet: { VaultLog.debug("Password set") },
            onCancel: { VaultLog.debug("Cancelled") }
        )
    }
} 
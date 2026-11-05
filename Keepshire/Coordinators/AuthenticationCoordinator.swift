import SwiftUI
import UIKit

final class AuthenticationCoordinator: ObservableObject {
    @Published var isAuthenticated = false
    @Published var isPasswordSet = false
    @Published var isAuthTypeSet = false
    @Published var selectedAuthType: AuthenticationType?
    @Published var isInBackground = false
    @Published var isCheckingBiometric = false
    @Published var shouldShowPasscode = false
    @Published var shouldShowPrivacyOverlay = false

    private let keychainManager: KeychainManaging
    private let biometricManager: any BiometricAuthManaging
    private let loginStateManager: any LoginStateManaging
    private let fileStorageManager: FileStorageManaging

    init(
        keychainManager: KeychainManaging = KeychainManager.shared,
        biometricManager: any BiometricAuthManaging = BiometricAuthManager.shared,
        loginStateManager: any LoginStateManaging = LoginStateManager.shared,
        fileStorageManager: FileStorageManaging = FileStorageManager.shared
    ) {
        self.keychainManager = keychainManager
        self.biometricManager = biometricManager
        self.loginStateManager = loginStateManager
        self.fileStorageManager = fileStorageManager
    }

    func handleAuthTypeSelected(_ authType: AuthenticationType) {
        selectedAuthType = authType
        isAuthTypeSet = true
        handlePasscodeSet()
    }

    func handleOnAppear() {
        isPasswordSet = keychainManager.isPasswordSet()
        isAuthTypeSet = keychainManager.isAuthenticationTypeSet()

        // Preserve migration for existing users who predate authentication type storage.
        if isPasswordSet && !isAuthTypeSet {
            keychainManager.setAuthenticationType(.password)
            isAuthTypeSet = true
            selectedAuthType = .password
        }

        if isAuthTypeSet && selectedAuthType == nil {
            selectedAuthType = keychainManager.getAuthenticationType()
        }

        if isPasswordSet && !isAuthenticated {
            checkBiometricAuthentication()
        }
    }

    func handleWillResignActive() {
        if isPasswordSet {
            shouldShowPrivacyOverlay = true
            keychainManager.setLastBackgroundTime()
        }
        isInBackground = true
    }

    func handleDidBecomeActive() {
        shouldShowPrivacyOverlay = false
        isInBackground = false
    }

    func handleWillEnterForeground() {
        shouldShowPrivacyOverlay = false

        if keychainManager.shouldRequireAuthentication() {
            isAuthenticated = false
            isCheckingBiometric = false
            shouldShowPasscode = false
            loginStateManager.resetLoginState()
            fileStorageManager.sweepTemporaryShareFiles()
            fileStorageManager.clearThumbnailCache()

            if isPasswordSet && !isAuthenticated {
                checkBiometricAuthentication()
            }
        } else if isAuthenticated {
            // Returning inside the auto-lock window skips unlock, so this is the only
            // chance to pick up anything the Share Extension staged while we were away.
            importSharedFilesIfUnlocked()
        }
    }

    func handleDidEnterBackground() {
        if isPasswordSet {
            shouldShowPrivacyOverlay = true
            VaultLog.debug("DEBUG: App entered background, showing enhanced privacy overlay")
        }
    }

    func handleScenePhaseChange(to newPhase: ScenePhase) {
        if newPhase == .background {
            handleWillResignActive()
        } else if newPhase == .active {
            handleDidBecomeActive()
        }
    }

    /// The setup screen has already created the vault and unlocked it.
    func handlePasscodeSet() {
        isPasswordSet = true
        isAuthenticated = true
        importSharedFilesIfUnlocked()
    }

    /// The lock screen has already checked the credential and, for a real login, unlocked the vault.
    func handleAuthentication() {
        isAuthenticated = true
        shouldShowPasscode = false
        biometricManager.resetFailureCount()
        fileStorageManager.sweepTemporaryShareFiles()
        didUnlock()
    }

    func handleSecurityLockTrigger() {
        guard isAuthenticated else { return }

        isAuthenticated = false
        loginStateManager.resetLoginState()
        keychainManager.setLastBackgroundTime()
        fileStorageManager.sweepTemporaryShareFiles()
        fileStorageManager.clearThumbnailCache()

        DispatchQueue.main.async {
            let impactFeedback = UIImpactFeedbackGenerator(style: .heavy)
            impactFeedback.impactOccurred()
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.checkBiometricAuthentication()
        }
    }

    private func checkBiometricAuthentication() {
        guard keychainManager.isBiometricEnabled(),
              biometricManager.canUseBiometrics(),
              fileStorageManager.hasBiometricUnlock else {
            shouldShowPasscode = true
            return
        }

        isCheckingBiometric = true
        shouldShowPasscode = false

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            guard let self = self else { return }
            // The Secure Enclave runs the biometric check and only then releases the vault key.
            self.fileStorageManager.unlockWithBiometrics(prompt: "Unlock your vault") { [weak self] success in
                guard let self = self else { return }
                self.isCheckingBiometric = false
                guard success else {
                    self.shouldShowPasscode = true
                    return
                }
                self.keychainManager.clearLastBackgroundTime()
                self.isAuthenticated = true
                self.loginStateManager.setLoginState(isFakeLogin: false)
                self.didUnlock()
            }
        }
    }

    private func didUnlock() {
        UnlockThrottle.shared.recordSuccess()
        // Builds before the key envelope stored the passcode itself; it must not outlive an upgrade.
        try? keychainManager.deletePassword()
        importSharedFilesIfUnlocked()
    }

    private func importSharedFilesIfUnlocked() {
        guard !loginStateManager.isFakeLogin else { return }
        fileStorageManager.importPendingSharedFiles()
    }
}

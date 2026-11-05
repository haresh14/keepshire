import Combine
import Foundation
import Testing
@testable import Keepshire

@MainActor
@Suite(.serialized)
struct AuthenticationCoordinatorTests {
    @Test func migratesExistingPasswordToPasswordAuthentication() {
        let keychain = FakeAuthenticationKeychain()
        keychain.password = "existing-password"
        let storage = FakeFileStorageManager(coreDataManager: TestCoreDataStore.reset())
        let coordinator = makeCoordinator(keychain: keychain, storage: storage)

        coordinator.handleOnAppear()

        #expect(coordinator.isPasswordSet)
        #expect(coordinator.isAuthTypeSet)
        #expect(coordinator.selectedAuthType == .password)
        #expect(keychain.authenticationType == .password)
        #expect(coordinator.shouldShowPasscode)
    }

    @Test func aSavedLockTypeWithoutAVaultStartsSetup() {
        // As after a restore to a new device: settings come back, the Keychain vault does not.
        let keychain = FakeAuthenticationKeychain()
        keychain.authenticationType = .passcode4
        let storage = FakeFileStorageManager(coreDataManager: TestCoreDataStore.reset())
        let coordinator = makeCoordinator(keychain: keychain, storage: storage)

        coordinator.handleOnAppear()

        #expect(!coordinator.isPasswordSet)
        #expect(!coordinator.isAuthTypeSet)
        #expect(!coordinator.shouldShowPasscode)
    }

    @Test func passcodeCompletionAuthenticatesWithoutReadingAStoredCredential() {
        let keychain = FakeAuthenticationKeychain()
        keychain.password = "vault-password"
        let storage = FakeFileStorageManager(coreDataManager: TestCoreDataStore.reset())
        let coordinator = makeCoordinator(keychain: keychain, storage: storage)

        coordinator.handlePasscodeSet()

        #expect(coordinator.isPasswordSet)
        #expect(coordinator.isAuthenticated)
        // The setup screen unlocked the vault; nothing stored is read back to do it again.
        #expect(storage.encryptionPasswords.isEmpty)
        #expect(storage.pendingShareImportCalls == 1)
    }

    @Test func unlockingRemovesAPasscodeLeftByEarlierBuilds() {
        let keychain = FakeAuthenticationKeychain()
        keychain.password = "vault-password"
        let storage = FakeFileStorageManager(coreDataManager: TestCoreDataStore.reset())
        let coordinator = makeCoordinator(keychain: keychain, storage: storage)

        coordinator.handleAuthentication()

        #expect(keychain.didDeleteLegacyPassword)
    }

    @Test func backgroundAndForegroundPreservePrivacyAndLockBehavior() {
        let keychain = FakeAuthenticationKeychain()
        keychain.password = "vault-password"
        keychain.authenticationType = .passcode4
        keychain.requireAuthentication = true
        let login = FakeLoginStateManager()
        login.setLoginState(isFakeLogin: true)
        let storage = FakeFileStorageManager(coreDataManager: TestCoreDataStore.reset())
        let coordinator = makeCoordinator(
            keychain: keychain,
            login: login,
            storage: storage
        )
        coordinator.handlePasscodeSet()
        #expect(storage.pendingShareImportCalls == 0)

        coordinator.handleWillResignActive()
        #expect(coordinator.shouldShowPrivacyOverlay)
        #expect(keychain.didSetBackgroundTime)

        coordinator.handleWillEnterForeground()
        #expect(!coordinator.isAuthenticated)
        #expect(!coordinator.shouldShowPrivacyOverlay)
        #expect(coordinator.shouldShowPasscode)
        #expect(!login.isFakeLogin)
    }

    @Test func foregroundingInsideTheLockWindowStillImportsSharedFiles() {
        let keychain = FakeAuthenticationKeychain()
        keychain.password = "vault-password"
        keychain.requireAuthentication = false
        let storage = FakeFileStorageManager(coreDataManager: TestCoreDataStore.reset())
        let coordinator = makeCoordinator(keychain: keychain, storage: storage)
        coordinator.handlePasscodeSet()
        #expect(storage.pendingShareImportCalls == 1)

        coordinator.handleWillEnterForeground()

        #expect(coordinator.isAuthenticated)
        #expect(storage.pendingShareImportCalls == 2)
    }

    @Test func foregroundingInsideTheLockWindowSkipsImportForFakeLogin() {
        let keychain = FakeAuthenticationKeychain()
        keychain.password = "vault-password"
        keychain.requireAuthentication = false
        let login = FakeLoginStateManager()
        login.setLoginState(isFakeLogin: true)
        let storage = FakeFileStorageManager(coreDataManager: TestCoreDataStore.reset())
        let coordinator = makeCoordinator(keychain: keychain, login: login, storage: storage)
        coordinator.handlePasscodeSet()

        coordinator.handleWillEnterForeground()

        #expect(storage.pendingShareImportCalls == 0)
    }

    @Test func newVaultIsOfferedARecoveryKeyUntilDeclined() {
        let keychain = FakeAuthenticationKeychain()
        let storage = FakeFileStorageManager(coreDataManager: TestCoreDataStore.reset())
        let coordinator = makeCoordinator(keychain: keychain, storage: storage)

        coordinator.handlePasscodeSet()
        #expect(coordinator.shouldOfferRecoveryKey)

        coordinator.declineRecoveryKeyOffer()
        #expect(!coordinator.shouldOfferRecoveryKey)
        coordinator.handleAuthentication()
        #expect(!coordinator.shouldOfferRecoveryKey)
    }

    @Test func unlockOffersARecoveryKeyOnlyToARealVaultWithoutOne() {
        let keychain = FakeAuthenticationKeychain()
        let storage = FakeFileStorageManager(coreDataManager: TestCoreDataStore.reset())
        storage.hasRecoveryKey = true
        let coordinator = makeCoordinator(keychain: keychain, storage: storage)
        coordinator.handleAuthentication()
        #expect(!coordinator.shouldOfferRecoveryKey)

        let login = FakeLoginStateManager()
        login.setLoginState(isFakeLogin: true)
        let decoy = makeCoordinator(
            keychain: keychain,
            login: login,
            storage: FakeFileStorageManager(coreDataManager: TestCoreDataStore.reset())
        )
        decoy.handleAuthentication()
        #expect(!decoy.shouldOfferRecoveryKey)
    }

    private func makeCoordinator(
        keychain: FakeAuthenticationKeychain,
        biometric: FakeAuthenticationBiometric = FakeAuthenticationBiometric(),
        login: FakeLoginStateManager = FakeLoginStateManager(),
        storage: FakeFileStorageManager
    ) -> AuthenticationCoordinator {
        AuthenticationCoordinator(
            keychainManager: keychain,
            biometricManager: biometric,
            loginStateManager: login,
            fileStorageManager: storage
        )
    }
}

private final class FakeAuthenticationKeychain: KeychainManaging {
    var password: String?
    var authenticationType: AuthenticationType?
    var biometricEnabled = false
    var requireAuthentication = false
    var didSetBackgroundTime = false

    var didDeleteLegacyPassword = false
    var declinedRecoveryKeyOffer = false

    func deletePassword() throws { didDeleteLegacyPassword = true }
    func isPasswordSet() -> Bool { password != nil }
    func setFakePassword(_ password: String) throws {}
    func verifyFakePassword(_ password: String) -> Bool { false }
    func deleteFakePassword() throws {}
    func isFakePasswordSet() -> Bool { false }
    func setBiometricEnabled(_ enabled: Bool) { biometricEnabled = enabled }
    func isBiometricEnabled() -> Bool { biometricEnabled }
    func setAuthenticationType(_ type: AuthenticationType) { authenticationType = type }
    func getAuthenticationType() -> AuthenticationType { authenticationType ?? .password }
    func isAuthenticationTypeSet() -> Bool { authenticationType != nil }
    func setLockTimeout(_ timeout: Int) {}
    func getLockTimeout() -> Int { 0 }
    func setLastBackgroundTime() { didSetBackgroundTime = true }
    func clearLastBackgroundTime() { didSetBackgroundTime = false }
    func shouldRequireAuthentication() -> Bool { requireAuthentication }
    func hasDeclinedRecoveryKeyOffer() -> Bool { declinedRecoveryKeyOffer }
    func setRecoveryKeyOfferDeclined(_ declined: Bool) { declinedRecoveryKeyOffer = declined }
    func clearAllKeychainData() {
        password = nil
        authenticationType = nil
    }
}

private final class FakeAuthenticationBiometric: ObservableObject, BiometricAuthManaging {
    var isAvailable = false

    func canUseBiometrics() -> Bool { isAvailable }
    func biometricType() -> BiometricType { isAvailable ? .faceID : .none }
    func authenticateWithBiometrics(
        reason: String,
        completion: @escaping (Bool, Error?) -> Void
    ) {
        completion(false, nil)
    }
    func resetFailureCount() {}
}

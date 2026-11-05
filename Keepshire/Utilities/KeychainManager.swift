//
//  KeychainManager.swift
//  Keepshire
//
//  Created on 10/07/25.
//

import Foundation
import LocalAuthentication
import Security

enum KeychainError: Error {
    case duplicateEntry
    case unknown(OSStatus)
    case noPassword
    case invalidData
}

enum AuthenticationType: String, CaseIterable {
    case passcode4 = "passcode4"
    case passcode6 = "passcode6"
    case password = "password"
    
    var displayName: String {
        switch self {
        case .passcode4: return "4-Digit Passcode"
        case .passcode6: return "6-Digit Passcode"
        case .password: return "Password"
        }
    }
    
    var isPasscode: Bool {
        return self == .passcode4 || self == .passcode6
    }
    
    var digitCount: Int? {
        switch self {
        case .passcode4: return 4
        case .passcode6: return 6
        case .password: return nil
        }
    }
}

class KeychainManager: KeychainManaging {
    static let shared = KeychainManager()
    
    private let service: String
    private let defaults: UserDefaults
    private let passwordKey = "userPassword"
    private let fakePasswordKey = "fakePassword"
    private let keyDerivationAccount = "vaultKeyDerivation"
    private let biometricKeyAccount = "vaultKeyBiometric"
    private let unlockThrottleAccount = "unlockThrottle"
    private let recoveryWrapAccount = "vaultKeyRecovery"
    private let recoveryKeyOfferDeclinedKey = "recoveryKeyOfferDeclined"
    private let biometricEnabledKey = "biometricEnabled"
    private let authTypeKey = "authenticationType"
    
    private init() {
        service = "dev.haresh.keepshire"
        defaults = .standard
    }

    /// Creates isolated Keychain and defaults namespaces for tests.
    init(service: String, defaults: UserDefaults) {
        self.service = service
        self.defaults = defaults
    }
    
    // MARK: - Credential

    /// Builds before the vault-key envelope kept the passcode itself here. It is only ever
    /// deleted now: the envelope is the sole stored form of the credential.
    func deletePassword() throws {
        try delete(account: passwordKey)
    }

    /// A vault exists once its key envelope does. Only a missing item means "not set": a locked
    /// or busy Keychain must not send an existing user back to first-run setup.
    func isPasswordSet() -> Bool {
        do {
            return try loadKeyMaterialData() != nil
        } catch {
            return true
        }
    }

    // MARK: - Fake Password Management

    /// Stores a one-way verifier, never the decoy credential itself.
    func saveFakePassword(_ password: String) throws {
        let verifier = try VaultCryptoService().makeVerifier(for: password)
        try upsert(JSONEncoder().encode(verifier), account: fakePasswordKey)
    }

    func setFakePassword(_ password: String) throws {
        try saveFakePassword(password)
    }

    func verifyFakePassword(_ password: String) -> Bool {
        guard let data = try? loadData(account: fakePasswordKey),
              let verifier = try? JSONDecoder().decode(CredentialVerifier.self, from: data) else {
            return false
        }
        return VaultCryptoService().matches(password, verifier: verifier)
    }

    func deleteFakePassword() throws {
        try delete(account: fakePasswordKey)
    }

    func isFakePasswordSet() -> Bool {
        (try? loadData(account: fakePasswordKey)) != nil
    }

    // MARK: - Authentication Type Management

    /// Kept as a fallback only; the type stored inside the key envelope wins.
    func setAuthenticationType(_ type: AuthenticationType) {
        defaults.set(type.rawValue, forKey: authTypeKey)
    }

    /// Read from the envelope, which stores the type in the same atomic write as the credential,
    /// so the lock screen's keypad can always enter whatever credential is stored.
    func getAuthenticationType() -> AuthenticationType {
        envelopeAuthenticationType()
            ?? defaults.string(forKey: authTypeKey).flatMap(AuthenticationType.init(rawValue:))
            ?? .passcode4 // Default to 4-digit passcode
    }

    func isAuthenticationTypeSet() -> Bool {
        envelopeAuthenticationType() != nil || defaults.string(forKey: authTypeKey) != nil
    }

    private func envelopeAuthenticationType() -> AuthenticationType? {
        guard let data = try? loadKeyMaterialData(),
              case .envelope(let envelope)? = StoredVaultKeyMaterial.decode(data),
              envelope.wraps.count == 1 else { return nil }
        return envelope.wraps[0].authType.flatMap(AuthenticationType.init(rawValue:))
    }

    // MARK: - Biometric Settings
    
    func setBiometricEnabled(_ enabled: Bool) {
        defaults.set(enabled, forKey: biometricEnabledKey)
    }
    
    func isBiometricEnabled() -> Bool {
        return defaults.bool(forKey: biometricEnabledKey)
    }
    
    // MARK: - App Lock State
    
    private let lastBackgroundTimeKey = "lastBackgroundTime"
    private let lockTimeoutKey = "lockTimeout"
    
    enum LockTimeout: Int, CaseIterable {
        case immediate = 0
        case fiveSeconds = 5
        case tenSeconds = 10
        case fifteenSeconds = 15
        case thirtySeconds = 30
        case oneMinute = 60
        case fiveMinutes = 300
        case never = -1
        
        var displayName: String {
            switch self {
            case .immediate: return "Immediately"
            case .fiveSeconds: return "5 Seconds"
            case .tenSeconds: return "10 Seconds"
            case .fifteenSeconds: return "15 Seconds"
            case .thirtySeconds: return "30 Seconds"
            case .oneMinute: return "1 Minute"
            case .fiveMinutes: return "5 Minutes"
            case .never: return "Never"
            }
        }
    }
    
    func setLockTimeout(_ timeout: Int) {
        defaults.set(timeout, forKey: lockTimeoutKey)
    }
    
    func getLockTimeout() -> Int {
        let rawValue = defaults.integer(forKey: lockTimeoutKey)
        // Check if key exists in UserDefaults - if not, default to 30 seconds
        if defaults.object(forKey: lockTimeoutKey) == nil {
            return LockTimeout.thirtySeconds.rawValue
        }
        return rawValue
    }
    
    func setLastBackgroundTime() {
        defaults.set(Date(), forKey: lastBackgroundTimeKey)
    }
    
    func shouldRequireAuthentication() -> Bool {
        let timeout = getLockTimeout()
        
        // If set to never, don't require authentication
        if timeout == LockTimeout.never.rawValue {
            return false
        }
        
        // If set to immediate, always require authentication
        if timeout == LockTimeout.immediate.rawValue {
            return true
        }
        
        guard let lastBackgroundTime = defaults.object(forKey: lastBackgroundTimeKey) as? Date else {
            return true // First launch
        }
        
        let timeInterval = Date().timeIntervalSince(lastBackgroundTime)
        return timeInterval > Double(timeout)
    }
    
    func clearLastBackgroundTime() {
        defaults.removeObject(forKey: lastBackgroundTimeKey)
    }
    
    // MARK: - Data Cleanup
    
    // MARK: - Vault key material (wrapped vault key, or a pre-envelope derivation record)

    func saveKeyMaterialData(_ data: Data) throws {
        try upsert(data, account: keyDerivationAccount)
    }

    /// Returns nil only when the item does not exist; every other failure throws.
    func loadKeyMaterialData() throws -> Data? {
        try loadData(account: keyDerivationAccount)
    }

    private func loadData(account: String) throws -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecMatchLimit as String: kSecMatchLimitOne,
            kSecReturnData as String: true
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound {
            return nil
        }
        guard status == errSecSuccess, let data = result as? Data else {
            throw KeychainError.unknown(status)
        }
        return data
    }

    private func delete(account: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unknown(status)
        }
    }

    func saveKeyDerivationRecord(_ record: VaultKeyDerivationRecord) throws {
        try saveKeyMaterialData(JSONEncoder().encode(record))
    }

    func loadKeyDerivationRecord() -> VaultKeyDerivationRecord? {
        guard let data = try? loadKeyMaterialData() else { return nil }
        return try? JSONDecoder().decode(VaultKeyDerivationRecord.self, from: data)
    }

    /// Updates in place so a crash or failure never leaves the item deleted but not re-added.
    private func upsert(_ data: Data, account: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        let attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        var status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if status == errSecItemNotFound {
            status = SecItemAdd(query.merging(attributes) { $1 } as CFDictionary, nil)
        }
        guard status == errSecSuccess else {
            throw KeychainError.unknown(status)
        }
    }

    func deleteKeyDerivationRecord() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: keyDerivationAccount
        ]
        SecItemDelete(query as CFDictionary)
    }

    // MARK: - Biometric vault key

    /// The Secure Enclave releases this item only after Face ID or Touch ID, and drops it when the
    /// enrolled biometrics change. Nothing app-side can skip that check.
    func saveBiometricVaultKey(_ keyData: Data) throws {
        var error: Unmanaged<CFError>?
        guard let access = SecAccessControlCreateWithFlags(
            nil,
            kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            .biometryCurrentSet,
            &error
        ) else {
            throw KeychainError.invalidData
        }
        // Items guarded by biometry cannot be updated without a prompt; replacing one only ever
        // costs Face ID unlock, never vault data, so delete-then-add is safe here.
        deleteBiometricVaultKey()
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: biometricKeyAccount,
            kSecValueData as String: keyData,
            kSecAttrAccessControl as String: access
        ]
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.unknown(status)
        }
    }

    /// Blocks while the system shows the biometric prompt. The match is required up front and the
    /// same context then opens the item, so a missing face fails here even where the Keychain's
    /// own check is not enforced (the Simulator has no Secure Enclave); on a device both apply.
    func loadBiometricVaultKey(prompt: String) throws -> Data? {
        let context = LAContext()
        context.localizedReason = prompt
        let matched = DispatchSemaphore(value: 0)
        var didMatch = false
        context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: prompt) { success, _ in
            didMatch = success
            matched.signal()
        }
        matched.wait()
        guard didMatch else { throw KeychainError.noPassword }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: biometricKeyAccount,
            kSecMatchLimit as String: kSecMatchLimitOne,
            kSecReturnData as String: true,
            kSecUseAuthenticationContext as String: context
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound {
            return nil
        }
        guard status == errSecSuccess, let data = result as? Data else {
            throw KeychainError.unknown(status)
        }
        return data
    }

    func hasBiometricVaultKey() -> Bool {
        let context = LAContext()
        context.interactionNotAllowed = true
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: biometricKeyAccount,
            kSecMatchLimit as String: kSecMatchLimitOne,
            kSecUseAuthenticationContext as String: context
        ]
        let status = SecItemCopyMatching(query as CFDictionary, nil)
        return status == errSecSuccess || status == errSecInteractionNotAllowed
    }

    func deleteBiometricVaultKey() {
        try? delete(account: biometricKeyAccount)
    }

    // MARK: - Recovery key

    func saveRecoveryWrapData(_ data: Data) throws {
        try upsert(data, account: recoveryWrapAccount)
    }

    /// Returns nil only when the item does not exist; every other failure throws.
    func loadRecoveryWrapData() throws -> Data? {
        try loadData(account: recoveryWrapAccount)
    }

    func deleteRecoveryWrap() {
        try? delete(account: recoveryWrapAccount)
    }

    /// Set when the user turns down the offer after unlock, so it is not repeated on every unlock.
    func hasDeclinedRecoveryKeyOffer() -> Bool {
        defaults.bool(forKey: recoveryKeyOfferDeclinedKey)
    }

    func setRecoveryKeyOfferDeclined(_ declined: Bool) {
        defaults.set(declined, forKey: recoveryKeyOfferDeclinedKey)
    }

    // MARK: - Unlock throttle

    func loadUnlockThrottleData() -> Data? {
        try? loadData(account: unlockThrottleAccount)
    }

    func saveUnlockThrottleData(_ data: Data) {
        try? upsert(data, account: unlockThrottleAccount)
    }

    func clearAllKeychainData() {
        VaultLog.debug("DEBUG: Clearing all keychain data...")
        
        // Clear password from keychain
        try? deletePassword()
        
        // Clear fake password from keychain
        try? deleteFakePassword()

        deleteKeyDerivationRecord()
        deleteBiometricVaultKey()
        deleteRecoveryWrap()
        try? delete(account: unlockThrottleAccount)
        
        VaultLog.debug("DEBUG: Keychain data cleared")
    }
    
    func clearAllUserDefaultsData() {
        VaultLog.debug("DEBUG: Clearing all UserDefaults data...")
        
        // Clear authentication settings
        defaults.removeObject(forKey: authTypeKey)
        defaults.removeObject(forKey: biometricEnabledKey)
        defaults.removeObject(forKey: recoveryKeyOfferDeclinedKey)
        
        // Clear lock timeout settings
        defaults.removeObject(forKey: lockTimeoutKey)
        defaults.removeObject(forKey: lastBackgroundTimeKey)
        
        // Clear biometric failure data (from BiometricAuthManager)
        defaults.removeObject(forKey: "biometricFailureCount")
        defaults.removeObject(forKey: "lastBiometricFailureTime")
        
        // Synchronize to ensure changes are written
        defaults.synchronize()
        
        VaultLog.debug("DEBUG: UserDefaults data cleared")
    }
} 
//
//  KeychainManager.swift
//  Keepshire
//
//  Created on 10/07/25.
//

import Foundation
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

    /// Whether this type's input UI can type `credential`. A password field accepts anything.
    func canEnter(_ credential: String) -> Bool {
        guard let digitCount else { return true }
        return credential.count == digitCount && credential.allSatisfy(\.isNumber)
    }

    static func inferred(from credential: String) -> AuthenticationType {
        [.passcode4, .passcode6].first { $0.canEnter(credential) } ?? .password
    }
}

class KeychainManager: KeychainManaging {
    static let shared = KeychainManager()
    
    private let service: String
    private let defaults: UserDefaults
    private let passwordKey = "userPassword"
    private let fakePasswordKey = "fakePassword"
    private let keyDerivationAccount = "vaultKeyDerivation"
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
    
    // MARK: - Password Management
    
    func savePassword(_ password: String) throws {
        guard let passwordData = password.data(using: .utf8) else {
            throw KeychainError.invalidData
        }
        
        try upsert(passwordData, account: passwordKey)
    }
    
    func getPassword() throws -> String {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: passwordKey,
            kSecMatchLimit as String: kSecMatchLimitOne,
            kSecReturnData as String: true
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess else {
            if status == errSecItemNotFound {
                throw KeychainError.noPassword
            }
            throw KeychainError.unknown(status)
        }
        
        guard let data = result as? Data,
              let password = String(data: data, encoding: .utf8) else {
            throw KeychainError.invalidData
        }
        
        return password
    }
    
    func deletePassword() throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: passwordKey
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unknown(status)
        }
    }
    
    /// Only a missing item means "not set". A locked or busy Keychain must not send an existing
    /// user back to first-run setup, where a new passcode would replace the one their vault key needs.
    func isPasswordSet() -> Bool {
        do {
            _ = try getPassword()
            return true
        } catch KeychainError.noPassword {
            return false
        } catch {
            return true
        }
    }
    
    // MARK: - Fake Password Management
    
    func saveFakePassword(_ password: String) throws {
        guard let passwordData = password.data(using: .utf8) else {
            throw KeychainError.invalidData
        }
        
        // Validate that fake password is different from main password
        if let mainPassword = try? getPassword(), mainPassword == password {
            throw KeychainError.duplicateEntry
        }
        
        try upsert(passwordData, account: fakePasswordKey)
    }
    
    func getFakePassword() throws -> String {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: fakePasswordKey,
            kSecMatchLimit as String: kSecMatchLimitOne,
            kSecReturnData as String: true
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess else {
            if status == errSecItemNotFound {
                throw KeychainError.noPassword
            }
            throw KeychainError.unknown(status)
        }
        
        guard let data = result as? Data,
              let password = String(data: data, encoding: .utf8) else {
            throw KeychainError.invalidData
        }
        
        return password
    }
    
    func deleteFakePassword() throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: fakePasswordKey
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unknown(status)
        }
    }
    
    func isFakePasswordSet() -> Bool {
        do {
            _ = try getFakePassword()
            return true
        } catch {
            return false
        }
    }
    
    func setFakePassword(_ password: String) throws {
        try saveFakePassword(password)
    }
    
    func validatePassword(_ inputPassword: String) -> (isValid: Bool, isFakeLogin: Bool) {
        do {
            let mainPassword = try getPassword()
            if inputPassword == mainPassword {
                return (true, false)
            }
            
            if isFakePasswordSet() {
                let fakePassword = try getFakePassword()
                if inputPassword == fakePassword {
                    return (true, true)
                }
            }
            
            return (false, false)
        } catch {
            return (false, false)
        }
    }
    
    // MARK: - Authentication Type Management
    
    func setAuthenticationType(_ type: AuthenticationType) {
        defaults.set(type.rawValue, forKey: authTypeKey)
    }
    
    /// The type is kept in UserDefaults and the credential in the Keychain, so a crash between the
    /// two writes can leave a keypad that cannot enter the stored credential. Whenever they disagree,
    /// the credential wins and the type is repaired, so the lock screen can always accept it.
    func getAuthenticationType() -> AuthenticationType {
        let stored = defaults.string(forKey: authTypeKey).flatMap(AuthenticationType.init(rawValue:))
        guard let password = try? getPassword() else {
            return stored ?? .passcode4 // Default to 4-digit passcode
        }
        if let stored, stored.canEnter(password) {
            return stored
        }
        let repaired = AuthenticationType.inferred(from: password)
        setAuthenticationType(repaired)
        return repaired
    }
    
    func isAuthenticationTypeSet() -> Bool {
        return defaults.string(forKey: authTypeKey) != nil
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
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: keyDerivationAccount,
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

    func clearAllKeychainData() {
        VaultLog.debug("DEBUG: Clearing all keychain data...")
        
        // Clear password from keychain
        try? deletePassword()
        
        // Clear fake password from keychain
        try? deleteFakePassword()

        deleteKeyDerivationRecord()
        
        VaultLog.debug("DEBUG: Keychain data cleared")
    }
    
    func clearAllUserDefaultsData() {
        VaultLog.debug("DEBUG: Clearing all UserDefaults data...")
        
        // Clear authentication settings
        defaults.removeObject(forKey: authTypeKey)
        defaults.removeObject(forKey: biometricEnabledKey)
        
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
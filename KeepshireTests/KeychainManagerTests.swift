//
//  KeychainManagerTests.swift
//  KeepshireTests
//
//  Created on 11/07/25.
//

import Testing
import Foundation
@testable import Keepshire

@Suite(.serialized)
struct KeychainManagerTests {
    private final class TestKeychain {
        let suiteName = "KeychainManagerTests-\(UUID().uuidString)"
        let defaults: UserDefaults
        let manager: KeychainManager

        init() {
            defaults = UserDefaults(suiteName: suiteName)!
            manager = KeychainManager(service: suiteName, defaults: defaults)
        }

        deinit {
            try? manager.deletePassword()
            try? manager.deleteFakePassword()
            manager.deleteKeyDerivationRecord()
            defaults.removePersistentDomain(forName: suiteName)
        }
    }
    
    // MARK: - Initialization Tests
    
    @Test func testKeychainManagerSingleton() async throws {
        let manager1 = KeychainManager.shared
        let manager2 = KeychainManager.shared
        
        #expect(manager1 === manager2, "KeychainManager should be a singleton")
    }
    
    // MARK: - Credential Tests

    private func storeEnvelope(_ manager: KeychainManager, authType: AuthenticationType?) throws {
        let crypto = VaultCryptoService()
        let wrap = try crypto.wrap(crypto.makeVaultKey(), password: "135790", authType: authType)
        try manager.saveKeyMaterialData(JSONEncoder().encode(VaultKeyEnvelope(wraps: [wrap])))
    }

    @Test func testVaultCountsAsSetOnlyOnceItsKeyIsStored() async throws {
        let testKeychain = TestKeychain()
        let manager = testKeychain.manager

        #expect(!manager.isPasswordSet())
        try storeEnvelope(manager, authType: .passcode6)
        #expect(manager.isPasswordSet())
    }

    @Test func testAuthTypeComesFromTheEnvelopeNotDefaults() async throws {
        let testKeychain = TestKeychain()
        let manager = testKeychain.manager

        // Defaults can lag behind a crash; the envelope is written with the credential itself.
        manager.setAuthenticationType(.passcode4)
        try storeEnvelope(manager, authType: .passcode6)
        #expect(manager.getAuthenticationType() == .passcode6)
        #expect(manager.isAuthenticationTypeSet())

        // Envelopes from earlier builds carry no type, so the stored default still applies.
        try storeEnvelope(manager, authType: nil)
        #expect(manager.getAuthenticationType() == .passcode4)
    }

    @Test func testFakePasswordIsStoredOnlyAsAVerifier() async throws {
        let testKeychain = TestKeychain()
        let manager = testKeychain.manager

        #expect(!manager.isFakePasswordSet())
        try manager.saveFakePassword("987654")

        #expect(manager.isFakePasswordSet())
        #expect(manager.verifyFakePassword("987654"))
        #expect(!manager.verifyFakePassword("987655"))
        #expect(!manager.verifyFakePassword(""))

        try manager.deleteFakePassword()
        #expect(!manager.isFakePasswordSet())
        #expect(!manager.verifyFakePassword("987654"))
    }

    @Test func testKeyDerivationRecordStorage() async throws {
        let testKeychain = TestKeychain()
        let manager = testKeychain.manager
        let record = VaultKeyDerivationRecord.makeCurrent(salt: Data(repeating: 9, count: 16))

        try manager.saveKeyDerivationRecord(record)
        #expect(manager.loadKeyDerivationRecord() == record)

        manager.clearAllKeychainData()
        #expect(manager.loadKeyDerivationRecord() == nil)
    }
    
    // MARK: - Authentication Type Tests
    
    @Test func testAuthenticationTypeSettings() async throws {
        let testKeychain = TestKeychain()
        let manager = testKeychain.manager
        
        // Test default state (should not be set initially)
        #expect(manager.isAuthenticationTypeSet() == false, "Auth type should not be set initially")
        
        // Test setting different auth types
        let testTypes: [AuthenticationType] = [.passcode4, .passcode6, .password]
        
        for authType in testTypes {
            manager.setAuthenticationType(authType)
            #expect(manager.isAuthenticationTypeSet() == true, "Auth type should be set")
            #expect(manager.getAuthenticationType() == authType, "Retrieved auth type should match set type")
        }
        
        // Test default fallback when no type is set
        testKeychain.defaults.removeObject(forKey: "authenticationType")
        let defaultType = manager.getAuthenticationType()
        #expect(defaultType == .passcode4, "Default auth type should be passcode4")
    }
    
    @Test func testAuthenticationTypeProperties() async throws {
        // Test passcode types
        #expect(AuthenticationType.passcode4.isPasscode == true, "passcode4 should be a passcode type")
        #expect(AuthenticationType.passcode6.isPasscode == true, "passcode6 should be a passcode type")
        #expect(AuthenticationType.password.isPasscode == false, "password should not be a passcode type")
        
        // Test digit counts
        #expect(AuthenticationType.passcode4.digitCount == 4, "passcode4 should have 4 digits")
        #expect(AuthenticationType.passcode6.digitCount == 6, "passcode6 should have 6 digits")
        #expect(AuthenticationType.password.digitCount == nil, "password should have no digit count")
        
        // Test display names
        #expect(AuthenticationType.passcode4.displayName == "4-Digit Passcode", "passcode4 display name should be correct")
        #expect(AuthenticationType.passcode6.displayName == "6-Digit Passcode", "passcode6 display name should be correct")
        #expect(AuthenticationType.password.displayName == "Password", "password display name should be correct")
    }
    
    // MARK: - Biometric Settings Tests
    
    @Test func testBiometricSettings() async throws {
        let testKeychain = TestKeychain()
        let manager = testKeychain.manager
        
        // Test default state
        let defaultState = manager.isBiometricEnabled()
        
        // Test enabling biometric
        manager.setBiometricEnabled(true)
        #expect(manager.isBiometricEnabled() == true, "Biometric should be enabled")
        
        // Test disabling biometric
        manager.setBiometricEnabled(false)
        #expect(manager.isBiometricEnabled() == false, "Biometric should be disabled")
        
        // Restore original state
        manager.setBiometricEnabled(defaultState)
    }
    
    // MARK: - Lock Timeout Tests
    
    @Test func testLockTimeoutSettings() async throws {
        let testKeychain = TestKeychain()
        let manager = testKeychain.manager
        
        // Test default timeout
        let defaultTimeout = manager.getLockTimeout()
        #expect(defaultTimeout == KeychainManager.LockTimeout.thirtySeconds.rawValue, "Default lock timeout should be 30 seconds")
        
        // Test setting different timeouts
        let testTimeouts: [KeychainManager.LockTimeout] = [
            .immediate, .fiveSeconds, .tenSeconds, .fifteenSeconds,
            .thirtySeconds, .oneMinute, .fiveMinutes, .never
        ]
        
        for timeout in testTimeouts {
            manager.setLockTimeout(timeout.rawValue)
            let retrievedTimeout = manager.getLockTimeout()
            #expect(retrievedTimeout == timeout.rawValue, "Lock timeout should be set correctly for \(timeout)")
        }
        
        // Restore default
        manager.setLockTimeout(defaultTimeout)
    }
    
    @Test func testLockTimeoutDisplayNames() async throws {
        let testCases: [(KeychainManager.LockTimeout, String)] = [
            (.immediate, "Immediately"),
            (.fiveSeconds, "5 Seconds"),
            (.tenSeconds, "10 Seconds"),
            (.fifteenSeconds, "15 Seconds"),
            (.thirtySeconds, "30 Seconds"),
            (.oneMinute, "1 Minute"),
            (.fiveMinutes, "5 Minutes"),
            (.never, "Never")
        ]
        
        for (timeout, expectedName) in testCases {
            #expect(timeout.displayName == expectedName, "Display name for \(timeout) should be \(expectedName)")
        }
    }
    
    // MARK: - Background Time Management Tests
    
    @Test func testBackgroundTimeManagement() async throws {
        let testKeychain = TestKeychain()
        let manager = testKeychain.manager
        
        // Clear any existing background time
        manager.clearLastBackgroundTime()
        
        // Test that authentication is required when no background time is set
        #expect(manager.shouldRequireAuthentication() == true, "Should require authentication when no background time is set")
        
        // Set background time
        manager.setLastBackgroundTime()
        
        // Test immediate timeout
        manager.setLockTimeout(KeychainManager.LockTimeout.immediate.rawValue)
        #expect(manager.shouldRequireAuthentication() == true, "Should always require authentication with immediate timeout")
        
        // Test never timeout
        manager.setLockTimeout(KeychainManager.LockTimeout.never.rawValue)
        #expect(manager.shouldRequireAuthentication() == false, "Should never require authentication with never timeout")
        
        // Cleanup
        manager.clearLastBackgroundTime()
        manager.setLockTimeout(KeychainManager.LockTimeout.thirtySeconds.rawValue)
    }
    
    @Test func testBackgroundTimeoutLogic() async throws {
        let testKeychain = TestKeychain()
        let manager = testKeychain.manager
        
        // Test with 5 second timeout
        manager.setLockTimeout(KeychainManager.LockTimeout.fiveSeconds.rawValue)
        manager.setLastBackgroundTime()
        
        // Immediately check - should not require auth
        #expect(manager.shouldRequireAuthentication() == false, "Should not require authentication immediately")
        
        // Wait a bit and check again (simulated by clearing and setting old time)
        manager.clearLastBackgroundTime()
        
        // Simulate old background time by directly setting it
        let oldDate = Date().addingTimeInterval(-10) // 10 seconds ago
        testKeychain.defaults.set(oldDate, forKey: "lastBackgroundTime")
        
        #expect(manager.shouldRequireAuthentication() == true, "Should require authentication after timeout period")
        
        // Cleanup
        manager.clearLastBackgroundTime()
        manager.setLockTimeout(KeychainManager.LockTimeout.thirtySeconds.rawValue)
    }
    
    @Test func testImmediateLockTimeoutBugFix() async throws {
        let testKeychain = TestKeychain()
        let manager = testKeychain.manager
        
        // This test specifically validates the fix for the "Immediately" timeout bug
        // where getLockTimeout() was incorrectly returning 30 instead of 0
        
        // Set timeout to "Immediately" (raw value 0)
        manager.setLockTimeout(KeychainManager.LockTimeout.immediate.rawValue)
        
        // Verify it correctly returns 0, not a default value
        let retrievedTimeout = manager.getLockTimeout()
        #expect(retrievedTimeout == 0, "Immediate timeout should return 0, not default value")
        #expect(retrievedTimeout == KeychainManager.LockTimeout.immediate.rawValue, "Retrieved timeout should match immediate raw value")
        
        // Verify shouldRequireAuthentication works correctly with immediate timeout
        manager.setLastBackgroundTime()
        #expect(manager.shouldRequireAuthentication() == true, "Should always require authentication with immediate timeout, regardless of background time")
        
        // Test all timeout values to ensure they're stored and retrieved correctly
        let allTimeouts: [KeychainManager.LockTimeout] = [
            .immediate, .fiveSeconds, .tenSeconds, .fifteenSeconds,
            .thirtySeconds, .oneMinute, .fiveMinutes, .never
        ]
        
        for timeout in allTimeouts {
            manager.setLockTimeout(timeout.rawValue)
            let retrieved = manager.getLockTimeout()
            #expect(retrieved == timeout.rawValue, "Timeout \(timeout) (raw: \(timeout.rawValue)) should be stored and retrieved correctly")
        }
        
        // Cleanup
        manager.clearLastBackgroundTime()
        manager.setLockTimeout(KeychainManager.LockTimeout.thirtySeconds.rawValue)
    }
    
    // MARK: - Error Handling Tests
    
    @Test func testKeychainErrorHandling() async throws {
        let testKeychain = TestKeychain()
        let manager = testKeychain.manager

        // Deleting a credential that was never stored is not an error.
        try manager.deletePassword()
        try manager.deleteFakePassword()
        #expect(manager.isPasswordSet() == false, "Should return false when no vault key is stored")
    }
    
    // MARK: - Data Persistence Tests
    
    @Test func testDataPersistence() async throws {
        let testKeychain = TestKeychain()
        let manager = testKeychain.manager

        try storeEnvelope(manager, authType: .password)
        manager.setBiometricEnabled(true)
        manager.setLockTimeout(KeychainManager.LockTimeout.oneMinute.rawValue)

        #expect(manager.isPasswordSet() == true, "Vault key should persist")
        #expect(manager.isBiometricEnabled() == true, "Biometric setting should persist")
        #expect(manager.getLockTimeout() == KeychainManager.LockTimeout.oneMinute.rawValue, "Lock timeout should persist")
    }
    
    // MARK: - Performance Tests
    
    @Test func testKeychainPerformance() async throws {
        let testKeychain = TestKeychain()
        let manager = testKeychain.manager
        let payload = Data(repeating: 7, count: 256)
        
        let startTime = CFAbsoluteTimeGetCurrent()
        for _ in 0..<10 {
            try manager.saveKeyMaterialData(payload)
            _ = try manager.loadKeyMaterialData()
            _ = manager.isPasswordSet()
        }
        let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime
        #expect(timeElapsed < 1.0, "Keychain operations should complete within 1 second")
    }
    
    // MARK: - Security Tests
    
    @Test func testCredentialsAreNeverStoredReadably() async throws {
        let testKeychain = TestKeychain()
        let manager = testKeychain.manager
        let fake = "DecoyPassword123!"

        try storeEnvelope(manager, authType: .password)
        try manager.saveFakePassword(fake)

        // The vault credential ("135790") and the decoy appear nowhere in plaintext.
        let stored = try #require(try manager.loadKeyMaterialData())
        #expect(stored.range(of: Data("135790".utf8)) == nil)
        for value in testKeychain.defaults.dictionaryRepresentation().values {
            #expect((value as? String) != fake)
        }
    }
}

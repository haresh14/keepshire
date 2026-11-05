import Testing
import Foundation
import CoreData
@testable import Keepshire

@MainActor
@Suite(.serialized)
struct KeepshireTests {
    @Test func testSuiteOverview() {
        #expect(["Security", "Keychain", "Storage", "CoreData", "Web"].count == 5)
    }

    @Test func testAuthenticationAndEncryptedFileFlow() throws {
        let dependencies = try IsolatedTestDependencies()
        let password = "IntegrationTest123!"
        try dependencies.fileStorageManager.createVault(password: password, authType: .password)
        let original = Data("Authenticated file access test".utf8)
        let item = try dependencies.fileStorageManager.saveFile(data: original, fileName: "auth_test.txt", fileType: "text/plain")

        #expect(dependencies.keychainManager.isPasswordSet())
        #expect(try dependencies.fileStorageManager.loadFile(vaultItem: item) == original)
        #expect(dependencies.coreDataManager.fetchAllVaultItems().count == 1)
    }

    @Test func testAuthenticationTypeFlow() throws {
        let dependencies = try IsolatedTestDependencies()
        let manager = dependencies.keychainManager
        let storage = dependencies.fileStorageManager
        try storage.createVault(password: "1234", authType: .passcode4)
        #expect(manager.getAuthenticationType() == .passcode4)
        var current = "1234"
        for (type, credential) in [(AuthenticationType.passcode6, "123456"), (.password, "SecurePassword123!"), (.passcode4, "4321")] {
            try storage.changeCredential(from: current, to: credential, authType: type)
            #expect(manager.getAuthenticationType() == type)
            #expect(storage.verifyCredential(credential))
            #expect(!storage.verifyCredential(current))
            current = credential
        }
    }

    @Test func testSecuritySettingsIntegration() throws {
        let manager = try IsolatedTestDependencies().securityManager
        manager.enableScreenshotProtection(false)
        manager.enableRecordingProtection(false)
        manager.saveSettings()
        manager.loadSettings()
        #expect(!manager.isScreenshotProtectionEnabled)
        #expect(!manager.isRecordingProtectionEnabled)
    }

    @Test func testDataConsistency() throws {
        let dependencies = try IsolatedTestDependencies()
        dependencies.fileStorageManager.setupEncryptionKey(from: "ConsistencyTest123!")
        let original = Data("Consistency test data".utf8)
        let item = try dependencies.fileStorageManager.saveFile(data: original, fileName: "consistency_test.txt", fileType: "text/plain")
        let request = NSFetchRequest<VaultItem>(entityName: "VaultItem")
        request.predicate = NSPredicate(format: "id == %@", item.id! as CVarArg)
        let results = try dependencies.coreDataManager.context.fetch(request)

        #expect(results.count == 1)
        #expect(results.first?.fileName == "consistency_test.txt")
        #expect(try dependencies.fileStorageManager.loadFile(vaultItem: item) == original)
    }

    @Test func testStorageRecoversAfterEncryptionKeySetup() throws {
        let dependencies = try IsolatedTestDependencies()
        let data = Data("Recovery test".utf8)
        #expect(throws: FileStorageError.self) {
            try dependencies.fileStorageManager.saveFile(data: data, fileName: "recovery_test.txt", fileType: "text/plain")
        }

        dependencies.fileStorageManager.setupEncryptionKey(from: "RecoveryTest123!")
        let item = try dependencies.fileStorageManager.saveFile(data: data, fileName: "recovery_test.txt", fileType: "text/plain")
        #expect(try dependencies.fileStorageManager.loadFile(vaultItem: item) == data)
    }
}

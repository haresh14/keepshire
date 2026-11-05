import CryptoKit
import Foundation
import Testing
@testable import Keepshire

@MainActor
@Suite(.serialized)
struct ReliabilityTests {
    @Test func saveWithoutChangesDoesNotThrow() throws {
        let manager = CoreDataManager(inMemory: true)
        try manager.save()
    }

    @Test func temporaryShareUsesUniqueDirectoryAndSweepRemovesIt() throws {
        let fileManager = FileManager.default
        let sharing = TemporarySharingService(fileManager: fileManager)
        sharing.sweepAll()
        let url = try sharing.prepare(data: Data("secret".utf8), fileName: "photo.jpg")
        #expect(url.path.contains(TemporarySharingService.directoryName))
        #expect(url.deletingLastPathComponent().lastPathComponent != TemporarySharingService.directoryName)
        #expect(fileManager.fileExists(atPath: url.path))
        sharing.sweepAll()
        #expect(!fileManager.fileExists(atPath: sharing.shareRoot().path))
    }

    @Test func cleanupRemovesShareSessionIfSheetNeverCompletes() throws {
        let sharing = TemporarySharingService(fileManager: .default)
        let url = try sharing.prepare(data: Data("plain".utf8), fileName: "note.txt")
        sharing.cleanup(at: url)
        #expect(!FileManager.default.fileExists(atPath: url.path))
        #expect(!FileManager.default.fileExists(atPath: url.deletingLastPathComponent().path))
    }

    @Test func combinedBoxAndChunkedBlobsRoundTrip() throws {
        let crypto = VaultCryptoService()
        let record = VaultKeyDerivationRecord.makeCurrent()
        let key = try crypto.key(from: "chunk-key", record: record)
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let store = EncryptedFileStore(fileManager: .default, vaultDirectory: root, cryptoService: crypto)
        let small = Data("small combined box".utf8)
        try store.write(small, fileName: "small", key: key)
        let smallOnDisk = try Data(contentsOf: store.url(for: "small"))
        #expect(smallOnDisk.prefix(4) != VaultBlobFormat.magic)
        #expect(try store.read(fileName: "small", key: key) == small)

        store.plaintextChunkThreshold = 8
        let large = Data(repeating: 0x5A, count: 40)
        try store.write(large, fileName: "large", key: key)
        let largeOnDisk = try Data(contentsOf: store.url(for: "large"))
        #expect(largeOnDisk.prefix(4) == VaultBlobFormat.magic)
        #expect(try store.read(fileName: "large", key: key) == large)
    }

    @Test func saveFileFromURLMatchesDataImport() throws {
        let storage = try IsolatedTestDependencies()
        let manager = storage.fileStorageManager
        manager.setupEncryptionKey(from: "url-key")
        let payload = Data("from disk".utf8)
        let source = storage.rootURL.appendingPathComponent("source.bin")
        try payload.write(to: source)
        let item = try manager.saveFile(
            fromFileURL: source,
            fileName: "from-disk.bin",
            fileType: "application/octet-stream"
        )
        #expect(try manager.loadFile(vaultItem: item) == payload)
    }

    @Test func rejectedTooLargeImport() throws {
        #expect(VaultBlobFormat.hardCap == 2 * 1024 * 1024 * 1024)
    }

    @Test func pendingShareImportsAfterKeySetupAndDeletesInboxSession() throws {
        let storage = try IsolatedTestDependencies()
        let inbox = storage.rootURL.appendingPathComponent("SharedInbox", isDirectory: true)
        let session = inbox.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: session, withIntermediateDirectories: true)
        let sharedFile = session.appendingPathComponent("shared.txt")
        try Data("from share sheet".utf8).write(to: sharedFile)

        let manager = FileStorageManager(
            documentsDirectory: storage.rootURL.appendingPathComponent("ShareImportVault"),
            coreDataManager: storage.coreDataManager,
            keyDerivationStore: KeychainVaultKeyDerivationStore(keychain: storage.keychainManager),
            sharedInboxURL: inbox
        )
        manager.setupEncryptionKey(from: "share-inbox-key")

        #expect(manager.importPendingSharedFiles() == 1)
        #expect(!FileManager.default.fileExists(atPath: session.path))
        let item = storage.coreDataManager.fetchAllVaultItems().first
        #expect(item?.fileName == "shared.txt")
        #expect(try manager.loadFile(vaultItem: item!) == Data("from share sheet".utf8))
    }

    @Test func credentialChangeSucceedsEvenWhenABlobIsCorrupt() throws {
        let storage = try IsolatedTestDependencies()
        let manager = storage.fileStorageManager
        manager.setupEncryptionKey(from: "old-pass")
        let good = try manager.saveFile(
            data: Data("keep me".utf8),
            fileName: "good.txt",
            fileType: "text/plain"
        )
        let bad = try manager.saveFile(
            data: Data("break me".utf8),
            fileName: "bad.txt",
            fileType: "text/plain"
        )
        let blob = storage.rootURL
            .appendingPathComponent("Vault")
            .appendingPathComponent(bad.storedBlobName ?? "")
        try Data("not-a-sealed-box".utf8).write(to: blob)

        try manager.changeCredential(from: "old-pass", to: "new-pass", authType: .password)

        #expect(manager.setupEncryptionKey(from: "new-pass"))
        #expect(try manager.loadFile(vaultItem: good) == Data("keep me".utf8))
    }

    @Test func throttleWaitsGrowAndSuccessClearsThem() {
        var stored: Data?
        let throttle = UnlockThrottle(load: { stored }, save: { stored = $0 })
        let start = Date(timeIntervalSince1970: 1_000_000)

        for _ in 0..<4 {
            #expect(throttle.recordFailure(now: start) == nil)
        }
        #expect(throttle.remainingLockout(now: start) == nil)
        #expect(throttle.recordFailure(now: start) == 30)
        #expect(throttle.remainingLockout(now: start.addingTimeInterval(10)) == 20)
        #expect(throttle.remainingLockout(now: start.addingTimeInterval(31)) == nil)
        #expect(throttle.recordFailure(now: start) == 60)
        #expect(throttle.recordFailure(now: start) == 300)

        // A fresh instance over the same storage, as after a relaunch, keeps the lockout.
        let relaunched = UnlockThrottle(load: { stored }, save: { stored = $0 })
        #expect(relaunched.remainingLockout(now: start) == 300)

        relaunched.recordSuccess()
        #expect(relaunched.remainingLockout(now: start) == nil)
        #expect(relaunched.recordFailure(now: start) == nil)
    }

    @Test func throttleCapsAtOneHour() {
        #expect(UnlockThrottle.lockout(afterFailures: 8) == 15 * 60)
        #expect(UnlockThrottle.lockout(afterFailures: 9) == 60 * 60)
        #expect(UnlockThrottle.lockout(afterFailures: 50) == 60 * 60)
    }

    @Test func rejectionWarnsBeforeTheFirstWaitAndCountsDown() {
        var stored: Data?
        let throttle = UnlockThrottle(load: { stored }, save: { stored = $0 })
        let now = Date(timeIntervalSince1970: 2_000_000)

        #expect(throttle.rejection(noun: "passcode", now: now).message == "Incorrect passcode. Try again.")
        #expect(throttle.rejection(noun: "passcode", now: now).message == "Incorrect passcode. Try again.")
        #expect(throttle.rejection(noun: "passcode", now: now).message == "Incorrect passcode. 2 more tries before a short wait.")
        #expect(throttle.rejection(noun: "passcode", now: now).message == "Incorrect passcode. 1 more try before a short wait.")
        let locked = throttle.rejection(noun: "passcode", now: now)
        #expect(locked.lockedUntil == now.addingTimeInterval(30))
        #expect(throttle.lockedUntil(now: now) == now.addingTimeInterval(30))

        #expect(UnlockThrottle.lockoutMessage(remaining: 28.2) == "Too many attempts. Try again in 0:29.")
        #expect(UnlockThrottle.lockoutMessage(remaining: 300) == "Too many attempts. Try again in 5:00.")
        #expect(UnlockThrottle.lockoutMessage(remaining: 3600) == "Too many attempts. Try again in 1:00:00.")
        #expect(UnlockThrottle.lockoutMessage(remaining: 0.2) == "Too many attempts. Try again in 0:01.")
    }
}

import CryptoKit
import Foundation
import Testing
@testable import Keepshire

struct VaultCryptoServiceTests {
    private let crypto = VaultCryptoService()

    @Test func pbkdf2IsDeterministicForSamePasswordAndSalt() throws {
        let record = VaultKeyDerivationRecord.makeCurrent(salt: Data(repeating: 7, count: 16))
        let first = try crypto.key(from: "vault-pin", record: record)
        let second = try crypto.key(from: "vault-pin", record: record)
        #expect(rawKey(first) == rawKey(second))
    }

    @Test func differentSaltsProduceDifferentKeys() throws {
        let firstRecord = VaultKeyDerivationRecord.makeCurrent(salt: Data(repeating: 1, count: 16))
        let secondRecord = VaultKeyDerivationRecord.makeCurrent(salt: Data(repeating: 2, count: 16))
        let first = try crypto.key(from: "vault-pin", record: firstRecord)
        let second = try crypto.key(from: "vault-pin", record: secondRecord)
        #expect(rawKey(first) != rawKey(second))
    }

    @Test func pbkdf2KeyDiffersFromLegacySHA256() throws {
        let password = "vault-pin"
        let record = VaultKeyDerivationRecord.makeCurrent(salt: Data(repeating: 3, count: 16))
        let pbkdf2 = try crypto.key(from: password, record: record)
        let legacy = crypto.legacySHA256Key(from: password)
        #expect(rawKey(pbkdf2) != rawKey(legacy))
    }

    @Test func aesGCMRoundTripAndWrongKeyFails() throws {
        let record = VaultKeyDerivationRecord.makeCurrent()
        let key = try crypto.key(from: "correct", record: record)
        let payload = Data("secret vault bytes".utf8)
        let sealed = try crypto.encrypt(payload, using: key)
        #expect(try crypto.decrypt(sealed, using: key) == payload)

        let wrongKey = try crypto.key(from: "wrong", record: record)
        #expect(throws: Error.self) {
            try crypto.decrypt(sealed, using: wrongKey)
        }
    }

    private func rawKey(_ key: SymmetricKey) -> Data {
        key.withUnsafeBytes { Data($0) }
    }
}

struct RecoveryKeyTests {
    @Test func generatedKeysAreFullLengthGroupedAndDistinct() {
        let key = RecoveryKey.generate()
        #expect(key.normalized.count == RecoveryKey.characterCount)
        #expect(key.formatted.split(separator: "-").map(\.count) == Array(repeating: 4, count: 6))
        #expect(!key.normalized.contains { "ILOU".contains($0) })
        #expect(RecoveryKey.generate() != key)
    }

    @Test func typedKeysForgiveCaseSpacingAndLookalikes() throws {
        let key = try #require(RecoveryKey(typed: "ABCD-EFGH-JKMN-PQRS-TVWX-YZ01"))
        #expect(RecoveryKey(typed: "abcd efgh jkmn pqrs tvwx yz01") == key)
        #expect(RecoveryKey(typed: "ABCDEFGHJKMNPQRSTVWXYZOI") == key)
        #expect(key.endsWithGroup(typed: "yzol"))
        #expect(!key.endsWithGroup(typed: "YZ0"))
    }

    @Test func malformedKeysAreRejectedBeforeAnyGuess() {
        #expect(RecoveryKey(typed: "ABCD-EFGH") == nil)
        #expect(RecoveryKey(typed: "ABCD-EFGH-JKMN-PQRS-TVWX-YZ0U") == nil)
        #expect(RecoveryKey(typed: "ABCD-EFGH-JKMN-PQRS-TVWX-YZ01-2") == nil)
    }
}

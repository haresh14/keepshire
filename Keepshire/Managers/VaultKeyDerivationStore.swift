import Foundation

/// What the Keychain holds for the vault key: the current envelope, or the bare derivation
/// record written by builds where the passcode-derived key encrypted files directly.
enum StoredVaultKeyMaterial: Equatable {
    case envelope(VaultKeyEnvelope)
    case derivationRecord(VaultKeyDerivationRecord)
}

protocol VaultKeyDerivationStoring {
    /// Returns nil only when nothing is stored. Any other Keychain failure throws, because
    /// treating "unreadable" as "absent" would mint a new key and orphan every file.
    func loadMaterial() throws -> StoredVaultKeyMaterial?
    /// Replaces the stored material in one step; a failed write leaves the previous value.
    func saveEnvelope(_ envelope: VaultKeyEnvelope) throws
    func deleteRecord()
}

extension StoredVaultKeyMaterial {
    static func decode(_ data: Data) -> StoredVaultKeyMaterial? {
        let decoder = JSONDecoder()
        if let envelope = try? decoder.decode(VaultKeyEnvelope.self, from: data) {
            return .envelope(envelope)
        }
        if let record = try? decoder.decode(VaultKeyDerivationRecord.self, from: data) {
            return .derivationRecord(record)
        }
        return nil
    }
}

final class InMemoryVaultKeyDerivationStore: VaultKeyDerivationStoring {
    private var material: StoredVaultKeyMaterial?

    func loadMaterial() throws -> StoredVaultKeyMaterial? {
        material
    }

    func saveEnvelope(_ envelope: VaultKeyEnvelope) throws {
        material = .envelope(envelope)
    }

    func deleteRecord() {
        material = nil
    }
}

final class KeychainVaultKeyDerivationStore: VaultKeyDerivationStoring {
    private let keychain: KeychainManager

    init(keychain: KeychainManager) {
        self.keychain = keychain
    }

    func loadMaterial() throws -> StoredVaultKeyMaterial? {
        guard let data = try keychain.loadKeyMaterialData() else { return nil }
        guard let material = StoredVaultKeyMaterial.decode(data) else {
            throw KeychainError.invalidData
        }
        return material
    }

    func saveEnvelope(_ envelope: VaultKeyEnvelope) throws {
        try keychain.saveKeyMaterialData(JSONEncoder().encode(envelope))
    }

    func deleteRecord() {
        keychain.deleteKeyDerivationRecord()
    }
}

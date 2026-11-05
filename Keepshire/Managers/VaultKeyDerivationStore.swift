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

    /// A second copy of the vault key that the Secure Enclave releases only after Face ID or Touch ID.
    func saveBiometricKey(_ keyData: Data) throws
    /// Blocks while the system shows the biometric prompt; returns nil when no copy is stored.
    func loadBiometricKey(prompt: String) throws -> Data?
    func hasBiometricKey() -> Bool
    func deleteBiometricKey()

    /// The vault key sealed under the recovery key, kept apart from the envelope so changing the
    /// passcode, which replaces the envelope, can never drop it.
    func saveRecoveryWrap(_ wrap: VaultKeyWrap) throws
    /// Returns nil only when none is stored; any other Keychain failure throws.
    func loadRecoveryWrap() throws -> VaultKeyWrap?
    func deleteRecoveryWrap()
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
    private var biometricKey: Data?
    private var recoveryWrap: VaultKeyWrap?

    func loadMaterial() throws -> StoredVaultKeyMaterial? {
        material
    }

    func saveEnvelope(_ envelope: VaultKeyEnvelope) throws {
        material = .envelope(envelope)
    }

    func deleteRecord() {
        material = nil
    }

    func saveBiometricKey(_ keyData: Data) throws {
        biometricKey = keyData
    }

    func loadBiometricKey(prompt: String) throws -> Data? {
        biometricKey
    }

    func hasBiometricKey() -> Bool {
        biometricKey != nil
    }

    func deleteBiometricKey() {
        biometricKey = nil
    }

    func saveRecoveryWrap(_ wrap: VaultKeyWrap) throws {
        recoveryWrap = wrap
    }

    func loadRecoveryWrap() throws -> VaultKeyWrap? {
        recoveryWrap
    }

    func deleteRecoveryWrap() {
        recoveryWrap = nil
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

    func saveBiometricKey(_ keyData: Data) throws {
        try keychain.saveBiometricVaultKey(keyData)
    }

    func loadBiometricKey(prompt: String) throws -> Data? {
        try keychain.loadBiometricVaultKey(prompt: prompt)
    }

    func hasBiometricKey() -> Bool {
        keychain.hasBiometricVaultKey()
    }

    func deleteBiometricKey() {
        keychain.deleteBiometricVaultKey()
    }

    func saveRecoveryWrap(_ wrap: VaultKeyWrap) throws {
        try keychain.saveRecoveryWrapData(JSONEncoder().encode(wrap))
    }

    func loadRecoveryWrap() throws -> VaultKeyWrap? {
        guard let data = try keychain.loadRecoveryWrapData() else { return nil }
        guard let wrap = try? JSONDecoder().decode(VaultKeyWrap.self, from: data) else {
            throw KeychainError.invalidData
        }
        return wrap
    }

    func deleteRecoveryWrap() {
        keychain.deleteRecoveryWrap()
    }
}

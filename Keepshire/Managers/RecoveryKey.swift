import Foundation
import Security

/// A random code that opens the vault when the passcode is forgotten. It seals its own copy of the
/// vault key, kept apart from the passcode's, and like the passcode it is never stored.
///
/// 24 characters from Crockford's base32 alphabet carry 120 random bits, far beyond guessing, and
/// leave out I, L, O and U so a handwritten copy reads back unambiguously.
struct RecoveryKey: Equatable {
    static let characterCount = 24
    static let groupLength = 4
    private static let alphabet = Array("0123456789ABCDEFGHJKMNPQRSTVWXYZ")

    /// The bare characters, which are what wrap and unwrap the vault key.
    let normalized: String

    /// "K7QM-3XRP-…", the form shown to the user and accepted back with or without the dashes.
    var formatted: String {
        stride(from: 0, to: normalized.count, by: Self.groupLength)
            .map { start in
                let from = normalized.index(normalized.startIndex, offsetBy: start)
                let to = normalized.index(from, offsetBy: Self.groupLength)
                return String(normalized[from..<to])
            }
            .joined(separator: "-")
    }

    static func generate() -> RecoveryKey {
        var bytes = [UInt8](repeating: 0, count: characterCount)
        if SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes) != errSecSuccess {
            bytes = bytes.map { _ in UInt8.random(in: 0...255) }
        }
        // 256 is a multiple of 32, so the low five bits of each byte are uniform.
        return RecoveryKey(normalized: String(bytes.map { alphabet[Int($0 & 31)] }))
    }

    /// Reads a typed key: case, spaces and dashes are ignored, and O, I and L count as 0, 1 and 1.
    /// Returns nil unless it is a whole key, so a typo is caught before it costs a guess.
    init?(typed text: String) {
        guard let characters = Self.normalize(text), characters.count == Self.characterCount else { return nil }
        normalized = characters
    }

    /// True when `typed` is this key's last group, read as forgivingly as a whole key.
    func endsWithGroup(typed: String) -> Bool {
        Self.normalize(typed) == String(normalized.suffix(Self.groupLength))
    }

    private static func normalize(_ text: String) -> String? {
        var characters: [Character] = []
        for character in text.uppercased() {
            switch character {
            case " ", "-", "\n", "\t": continue
            case "O": characters.append("0")
            case "I", "L": characters.append("1")
            default:
                guard alphabet.contains(character) else { return nil }
                characters.append(character)
            }
        }
        return String(characters)
    }

    private init(normalized: String) {
        self.normalized = normalized
    }
}

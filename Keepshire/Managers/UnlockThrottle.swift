import Foundation

/// Slows guessing after repeated wrong credentials. A 4-digit passcode has only 10,000 values, so
/// without this anyone holding the phone could try them all. The state lives in the Keychain, so
/// relaunching the app does not reset it, and a successful unlock clears it.
final class UnlockThrottle {
    static let shared = UnlockThrottle(
        load: { KeychainManager.shared.loadUnlockThrottleData() },
        save: { KeychainManager.shared.saveUnlockThrottleData($0) }
    )

    private struct State: Codable {
        var failures = 0
        var lockedUntil: Date?
    }

    private let load: () -> Data?
    private let save: (Data) -> Void

    init(load: @escaping () -> Data?, save: @escaping (Data) -> Void) {
        self.load = load
        self.save = save
    }

    /// Free tries first, then waits that grow like the iPhone's own lock screen.
    static func lockout(afterFailures failures: Int) -> TimeInterval {
        switch failures {
        case ..<freeAttempts: return 0
        case freeAttempts: return 30
        case 6: return 60
        case 7: return 5 * 60
        case 8: return 15 * 60
        default: return 60 * 60
        }
    }

    /// Seconds left before another attempt is allowed, or nil when one is allowed now.
    func remainingLockout(now: Date = Date()) -> TimeInterval? {
        guard let lockedUntil = state.lockedUntil, lockedUntil > now else { return nil }
        return lockedUntil.timeIntervalSince(now)
    }

    /// Records a wrong credential and returns the wait it now imposes, if any.
    @discardableResult
    func recordFailure(now: Date = Date()) -> TimeInterval? {
        var state = state
        state.failures += 1
        let wait = Self.lockout(afterFailures: state.failures)
        state.lockedUntil = wait > 0 ? now.addingTimeInterval(wait) : nil
        persist(state)
        return wait > 0 ? wait : nil
    }

    func recordSuccess() {
        persist(State())
    }

    /// When the current lockout ends, or nil when an attempt is allowed now.
    func lockedUntil(now: Date = Date()) -> Date? {
        guard let lockedUntil = state.lockedUntil, lockedUntil > now else { return nil }
        return lockedUntil
    }

    /// Records a wrong credential and says what to show: a short message, or the lockout it caused.
    func rejection(noun: String, now: Date = Date()) -> (message: String, lockedUntil: Date?) {
        if let wait = recordFailure(now: now) {
            return ("Incorrect \(noun).", now.addingTimeInterval(wait))
        }
        let left = Self.freeAttempts - state.failures
        guard left <= 2 else { return ("Incorrect \(noun). Try again.", nil) }
        return ("Incorrect \(noun). \(left) more \(left == 1 ? "try" : "tries") before a short wait.", nil)
    }

    /// "Too many attempts. Try again in 0:28" — a clock under an hour, so the countdown reads naturally.
    static func lockoutMessage(remaining: TimeInterval) -> String {
        let total = max(1, Int(remaining.rounded(.up)))
        let clock = total >= 3600
            ? "\(total / 3600):" + String(format: "%02d:%02d", (total % 3600) / 60, total % 60)
            : "\(total / 60):" + String(format: "%02d", total % 60)
        return "Too many attempts. Try again in \(clock)."
    }

    private static let freeAttempts = 5

    private var state: State {
        guard let data = load(), let state = try? JSONDecoder().decode(State.self, from: data) else {
            return State()
        }
        return state
    }

    private func persist(_ state: State) {
        guard let data = try? JSONEncoder().encode(state) else { return }
        save(data)
    }
}

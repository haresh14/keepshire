import SwiftUI
import UIKit

/// The message line under a credential field. It always occupies the same space, so a message
/// appearing or clearing never moves the field or the keypad, and during a lockout it counts
/// down live instead of showing a frozen number.
struct CredentialFeedback: View {
    let message: String?
    var lockedUntil: Date? = nil

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let text = displayedText(at: context.date)
            Label {
                Text(text ?? " ")
                    .monospacedDigit()
            } icon: {
                Image(systemName: isLocked(at: context.date) ? "lock.fill" : "exclamationmark.circle.fill")
            }
            .font(.footnote.weight(.medium))
            .foregroundStyle(.red)
            .multilineTextAlignment(.center)
            .lineLimit(2, reservesSpace: true)
            .frame(maxWidth: .infinity)
            .opacity(text == nil ? 0 : 1)
            .animation(.easeOut(duration: 0.2), value: text)
            .accessibilityHidden(text == nil)
        }
    }

    private func isLocked(at now: Date) -> Bool {
        (lockedUntil.map { $0 > now }) ?? false
    }

    private func displayedText(at now: Date) -> String? {
        if let lockedUntil, lockedUntil > now {
            return UnlockThrottle.lockoutMessage(remaining: lockedUntil.timeIntervalSince(now))
        }
        return message
    }
}

/// Shakes a field sideways, the platform's cue for a rejected credential.
private struct ShakeEffect: GeometryEffect {
    var animatableData: CGFloat

    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(CGAffineTransform(translationX: 8 * sin(animatableData * .pi * 4), y: 0))
    }
}

extension View {
    /// Shakes once each time `trigger` increases.
    func shake(_ trigger: Int) -> some View {
        modifier(ShakeEffect(animatableData: CGFloat(trigger)))
            .animation(.linear(duration: 0.4), value: trigger)
    }
}

/// Feedback state for one credential entry: the message, a lockout end, and the shake count.
/// Each screen keeps one; `reject` and `clear` drive the whole presentation.
struct CredentialFeedbackState {
    private(set) var message: String?
    private(set) var lockedUntil: Date?
    private(set) var shakes = 0
    private var messageID = UUID()

    var isLocked: Bool {
        (lockedUntil.map { $0 > Date() }) ?? false
    }

    /// Shows `message`, shakes the field, plays the error haptic, and announces it to VoiceOver.
    /// Returns an id that `clear(ifStill:)` uses so an older timer never hides a newer message.
    @discardableResult
    mutating func reject(_ message: String, lockedUntil: Date? = nil) -> UUID {
        self.message = message
        self.lockedUntil = lockedUntil
        shakes += 1
        messageID = UUID()
        UINotificationFeedbackGenerator().notificationOccurred(.error)
        let spoken = lockedUntil.map { UnlockThrottle.lockoutMessage(remaining: $0.timeIntervalSinceNow) } ?? message
        UIAccessibility.post(notification: .announcement, argument: spoken)
        return messageID
    }

    /// Shows the lockout already in force, without counting it as a new rejection.
    @discardableResult
    mutating func showLockout(until lockedUntil: Date) -> UUID {
        message = nil
        self.lockedUntil = lockedUntil
        messageID = UUID()
        return messageID
    }

    mutating func clear(ifStill id: UUID? = nil) {
        if let id, id != messageID { return }
        message = nil
        lockedUntil = nil
    }
}

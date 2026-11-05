import SwiftUI
import UniformTypeIdentifiers

/// Creates a recovery key: explains it, shows it once, and stores it only after the user types
/// part of it back, so a key that was never written down is never the one the vault relies on.
struct RecoveryKeyView: View {
    private enum Step {
        case intro
        case reveal
        case confirm
    }

    /// True when a recovery key already exists and this one will replace it.
    let isReplacing: Bool
    let onFinish: () -> Void
    /// Shown as "Not Now" on the intro, for offers the user did not ask for.
    let onDecline: (() -> Void)?
    /// Shown as "Turn Off Recovery Key" when a key exists, after a confirmation.
    let onTurnOff: (() -> Void)?

    @Environment(\.dismiss) private var dismiss
    @State private var step: Step = .intro
    @State private var recoveryKey = RecoveryKey.generate()
    @State private var confirmation = ""
    @State private var feedback = CredentialFeedbackState()
    @State private var didCopy = false
    @State private var isConfirmingTurnOff = false
    @FocusState private var isConfirmationFocused: Bool

    init(
        isReplacing: Bool = false,
        onFinish: @escaping () -> Void,
        onDecline: (() -> Void)? = nil,
        onTurnOff: (() -> Void)? = nil
    ) {
        self.isReplacing = isReplacing
        self.onFinish = onFinish
        self.onDecline = onDecline
        self.onTurnOff = onTurnOff
    }

    var body: some View {
        NavigationStack {
            GeometryReader { proxy in
                ScrollView {
                    VStack(spacing: 28) {
                        switch step {
                        case .intro: introSection
                        case .reveal: revealSection
                        case .confirm: confirmSection
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 16)
                    .frame(maxWidth: 520)
                    // Centred when it fits; scrolls on small screens or large text.
                    .frame(maxWidth: .infinity, minHeight: proxy.size.height)
                }
                .scrollBounceBehavior(.basedOnSize)
            }
            .background(KeepshireBackground())
            .navigationTitle("Recovery Key")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel", action: cancel)
                        .foregroundColor(KeepshireTheme.accent)
                }
            }
        }
        .interactiveDismissDisabled(step != .intro)
        .alert("Turn Off Recovery Key?", isPresented: $isConfirmingTurnOff) {
            Button("Cancel", role: .cancel) {}
            Button("Turn Off", role: .destructive) {
                onTurnOff?()
                dismiss()
            }
        } message: {
            Text("Your saved recovery key will stop working. If you then forget your passcode, your files cannot be recovered.")
        }
    }

    // MARK: - Steps

    private var introSection: some View {
        VStack(spacing: 24) {
            KeepshireHero(
                artwork: .symbol("key.horizontal.fill"),
                title: isReplacing ? "Your recovery key is on" : "Create a recovery key",
                subtitle: isReplacing
                    ? "If you lost the key you saved, create a new one. Your current key will stop working."
                    : "If you forget your passcode, this key is the only way back into your vault. No one, including us, can recover it for you.",
                artworkSize: 64
            )
            VStack(spacing: 12) {
                Button(isReplacing ? "Create New Key" : "Create Recovery Key") {
                    withAnimation(.easeInOut(duration: 0.25)) { step = .reveal }
                }
                .buttonStyle(KeepshirePrimaryButtonStyle())
                if let onDecline {
                    Button("Not Now", action: onDecline)
                        .font(.system(.body, design: .rounded, weight: .medium))
                        .foregroundColor(KeepshireTheme.accent)
                }
                if onTurnOff != nil {
                    Button("Turn Off Recovery Key", role: .destructive) { isConfirmingTurnOff = true }
                        .font(.system(.body, design: .rounded, weight: .medium))
                        .foregroundColor(.red)
                        .accessibilityIdentifier("recoveryKey.turnOff")
                }
            }
        }
    }

    private var revealSection: some View {
        VStack(spacing: 24) {
            KeepshireHero(
                artwork: .symbol("key.horizontal.fill"),
                title: "Save your recovery key",
                subtitle: "Write it down or save it somewhere safe outside this app, such as the Passwords app. It is shown only now.",
                artworkSize: 64
            )
            // Three groups a line, so the key never breaks mid-group or leaves a lone group behind.
            Text(displayedKey)
                .font(.system(.title3, design: .monospaced, weight: .semibold))
                .multilineTextAlignment(.center)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity)
                .keepshireCard()
                .accessibilityLabel(spokenKey)
                .accessibilityIdentifier("recoveryKey.value")
            HStack(spacing: 12) {
                Button(action: copyKey) {
                    Label(didCopy ? "Copied" : "Copy", systemImage: didCopy ? "checkmark" : "doc.on.doc")
                }
                .buttonStyle(KeepshireSecondaryButtonStyle())
                ShareLink(item: shareText) {
                    Label("Save", systemImage: "square.and.arrow.up")
                }
                .buttonStyle(KeepshireSecondaryButtonStyle())
            }
            Button("I've Saved It") {
                withAnimation(.easeInOut(duration: 0.25)) { step = .confirm }
                isConfirmationFocused = true
            }
            .buttonStyle(KeepshirePrimaryButtonStyle())
        }
    }

    private var confirmSection: some View {
        VStack(spacing: 20) {
            KeepshireHero(
                artwork: .symbol("checkmark.shield.fill"),
                title: "Confirm your recovery key",
                subtitle: "Enter the last \(RecoveryKey.groupLength) characters of the key you saved.",
                artworkSize: 64
            )
            TextField("Last \(RecoveryKey.groupLength) characters", text: $confirmation)
                .textFieldStyle(.plain)
                .font(.system(.title3, design: .monospaced, weight: .semibold))
                .multilineTextAlignment(.center)
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
                .focused($isConfirmationFocused)
                .onSubmit(confirm)
                .onChange(of: confirmation) { _, value in
                    if !value.isEmpty { feedback.clear() }
                }
                .keepshireFieldStyle()
                .shake(feedback.shakes)
                .accessibilityIdentifier("recoveryKey.confirmation")
            CredentialFeedback(message: feedback.message, lockedUntil: nil)
            Button("Turn On Recovery Key", action: confirm)
                .buttonStyle(KeepshirePrimaryButtonStyle())
                .disabled(confirmation.isEmpty)
            Button("Show Key Again") {
                confirmation = ""
                feedback.clear()
                withAnimation(.easeInOut(duration: 0.25)) { step = .reveal }
            }
            .font(.system(.body, design: .rounded, weight: .medium))
            .foregroundColor(KeepshireTheme.accent)
        }
    }

    // MARK: - Actions

    private var displayedKey: String {
        let groups = recoveryKey.formatted.split(separator: "-")
        return groups.prefix(3).joined(separator: "-") + "\n" + groups.dropFirst(3).joined(separator: "-")
    }

    private var shareText: String {
        "\(AppMetadata.displayName) recovery key: \(recoveryKey.formatted)"
    }

    /// Read one character at a time, so VoiceOver does not try to pronounce the groups as words.
    private var spokenKey: String {
        recoveryKey.formatted.map { $0 == "-" ? "," : String($0) }.joined(separator: " ")
    }

    /// Kept on this device only and cleared after two minutes, so the key does not linger in
    /// Universal Clipboard or the pasteboard.
    private func copyKey() {
        UIPasteboard.general.setItems(
            [[UTType.plainText.identifier: recoveryKey.formatted]],
            options: [.localOnly: true, .expirationDate: Date().addingTimeInterval(120)]
        )
        didCopy = true
    }

    private func confirm() {
        guard recoveryKey.endsWithGroup(typed: confirmation) else {
            feedback.reject("That doesn't match. Check the key you saved.")
            confirmation = ""
            return
        }
        do {
            try FileStorageManager.shared.saveRecoveryKey(recoveryKey)
            onFinish()
            dismiss()
        } catch {
            VaultLog.error("Could not save the recovery key: \(error)")
            feedback.reject("Could not turn on the recovery key. Try again.")
        }
    }

    /// Cancelling an offer counts as declining it, so it is not repeated on every unlock.
    private func cancel() {
        onDecline?()
        dismiss()
    }
}

#Preview {
    RecoveryKeyView(onFinish: {})
}

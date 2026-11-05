//
//  CustomNumberPadView.swift
//  Keepshire
//
//  Created on 12/07/25.
//

import SwiftUI

/// The key in the bottom-left slot that unlocks with Face ID or Touch ID.
struct BiometricKey {
    let systemImage: String
    let label: String
    let action: () -> Void
}

struct CustomNumberPadView: View {
    let onNumberTapped: (String) -> Void
    let onBackspaceTapped: () -> Void
    let onHelpTapped: (() -> Void)?
    let biometricKey: BiometricKey?
    /// Dims and disables the digit and delete keys only, so biometrics stay usable during a lockout.
    let keysDisabled: Bool
    @ScaledMetric(relativeTo: .title2) private var keySize: CGFloat = Self.baseKeySize

    static let baseKeySize: CGFloat = 76
    static let maxKeySize: CGFloat = 96
    static let columnSpacing: CGFloat = 24
    static let rowSpacing: CGFloat = 14

    /// Width of the three key columns, so other views (the code boxes) can match it.
    static func width(forKeySize keySize: CGFloat) -> CGFloat {
        let size = min(keySize, maxKeySize)
        return size * 3 + columnSpacing * 2
    }
    
    init(
        onNumberTapped: @escaping (String) -> Void,
        onBackspaceTapped: @escaping () -> Void,
        onHelpTapped: (() -> Void)? = nil,
        biometricKey: BiometricKey? = nil,
        keysDisabled: Bool = false
    ) {
        self.onNumberTapped = onNumberTapped
        self.onBackspaceTapped = onBackspaceTapped
        self.onHelpTapped = onHelpTapped
        self.biometricKey = biometricKey
        self.keysDisabled = keysDisabled
    }
    
    private let numbers = [
        ["1", "2", "3"],
        ["4", "5", "6"],
        ["7", "8", "9"],
        ["?", "0", "⌫"]
    ]
    
    var body: some View {
        VStack(spacing: Self.rowSpacing) {
            ForEach(numbers, id: \.self) { row in
                HStack(spacing: Self.columnSpacing) {
                    ForEach(row, id: \.self) { item in
                        if item == "?", let biometricKey {
                            BiometricKeyButton(key: biometricKey, size: min(keySize, Self.maxKeySize))
                        } else if item == "?" && onHelpTapped == nil {
                            // No help action here: keep the slot so the grid stays aligned.
                            Color.clear
                                .frame(width: min(keySize, Self.maxKeySize), height: min(keySize, Self.maxKeySize))
                                .accessibilityHidden(true)
                        } else {
                            NumberPadButton(
                                text: item,
                                size: min(keySize, Self.maxKeySize),
                                action: {
                                    if item == "⌫" {
                                        onBackspaceTapped()
                                    } else if item == "?" {
                                        onHelpTapped?()
                                    } else if !item.isEmpty {
                                        onNumberTapped(item)
                                    }
                                }
                            )
                            .disabled(keysDisabled)
                            .opacity(keysDisabled ? 0.45 : 1)
                            .animation(.easeOut(duration: 0.2), value: keysDisabled)
                        }
                    }
                }
            }
        }
        // Numeric order must stay 1–9 in every locale.
        .environment(\.layoutDirection, .leftToRight)
    }
}

struct NumberPadButton: View {
    let text: String
    let size: CGFloat
    let action: () -> Void

    private var isUtilityKey: Bool { text == "⌫" || text == "?" }
    
    var body: some View {
        Button(action: action) {
            ZStack {
                if !isUtilityKey {
                    Circle()
                        .fill(Color(.secondarySystemGroupedBackground))
                        .shadow(color: .black.opacity(0.06), radius: 6, y: 2)
                    Circle()
                        .strokeBorder(Color(.separator).opacity(0.3), lineWidth: 0.5)
                }
                
                if text == "⌫" {
                    Image(systemName: "delete.left")
                        .font(.system(size: 22, weight: .medium))
                        .foregroundColor(.primary)
                } else if text == "?" {
                    Image(systemName: "questionmark")
                        .font(.title2)
                        .foregroundColor(.primary)
                } else {
                    Text(text)
                        .font(.system(size: 30, weight: .medium, design: .rounded))
                        .foregroundColor(.primary)
                }
            }
            .frame(width: size, height: size)
            .contentShape(Circle())
        }
        .buttonStyle(NumberPadButtonStyle())
        .frame(minWidth: 44, minHeight: 44)
        .accessibilityIdentifier(text == "⌫" ? "keypad.delete" : text == "?" ? "keypad.help" : "keypad.\(text)")
        .accessibilityLabel(text == "⌫" ? "Delete" : text == "?" ? "Help" : text)
    }
}

/// Drawn like the delete key, a bare glyph, so it reads as a utility rather than a digit.
struct BiometricKeyButton: View {
    let key: BiometricKey
    let size: CGFloat

    var body: some View {
        Button(action: key.action) {
            Image(systemName: key.systemImage)
                .font(.system(size: 28, weight: .regular))
                .foregroundStyle(KeepshireTheme.accent)
                .frame(width: size, height: size)
                .contentShape(Circle())
        }
        .buttonStyle(NumberPadButtonStyle())
        .frame(minWidth: 44, minHeight: 44)
        .accessibilityIdentifier("keypad.biometric")
        .accessibilityLabel(key.label)
    }
}

struct NumberPadButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.92 : 1.0)
            .brightness(configuration.isPressed ? -0.06 : 0)
            .animation(.smooth(duration: 0.12), value: configuration.isPressed)
    }
}

#Preview {
    CustomNumberPadView(
        onNumberTapped: { number in
            VaultLog.debug("Number tapped: \(number)")
        },
        onBackspaceTapped: {
            VaultLog.debug("Backspace tapped")
        },
        onHelpTapped: {
            VaultLog.debug("Help tapped")
        }
    )
} 
//
//  CustomNumberPadView.swift
//  Keepshire
//
//  Created on 12/07/25.
//

import SwiftUI

struct CustomNumberPadView: View {
    let onNumberTapped: (String) -> Void
    let onBackspaceTapped: () -> Void
    let onHelpTapped: (() -> Void)?
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
    
    init(onNumberTapped: @escaping (String) -> Void, onBackspaceTapped: @escaping () -> Void, onHelpTapped: (() -> Void)? = nil) {
        self.onNumberTapped = onNumberTapped
        self.onBackspaceTapped = onBackspaceTapped
        self.onHelpTapped = onHelpTapped
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
                        if item == "?" && onHelpTapped == nil {
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
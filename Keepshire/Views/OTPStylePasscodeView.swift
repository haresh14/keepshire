//
//  OTPStylePasscodeView.swift
//  Keepshire
//
//  Created on 10/07/25.
//

import SwiftUI

struct OTPStylePasscodeView: View {
    let digitCount: Int
    @Binding var passcode: String
    @State private var digits: [String]
    @State private var currentIndex: Int = 0
    let onHelpTapped: (() -> Void)?
    
    init(digitCount: Int, passcode: Binding<String>, onHelpTapped: (() -> Void)? = nil) {
        self.digitCount = digitCount
        self._passcode = passcode
        self._digits = State(initialValue: Array(repeating: "", count: digitCount))
        self.onHelpTapped = onHelpTapped
    }
    
    /// Matches `CustomNumberPadView`'s key size so the boxes span exactly the keypad width.
    @ScaledMetric(relativeTo: .title2) private var keySize: CGFloat = CustomNumberPadView.baseKeySize

    private var boxSpacing: CGFloat { digitCount > 4 ? 8 : 12 }

    var body: some View {
        VStack(spacing: 32) {
            // Digit display
            HStack(spacing: boxSpacing) {
                ForEach(0..<digitCount, id: \.self) { index in
                    DigitDisplay(
                        digit: digits[index],
                        isActive: index == currentIndex,
                        onTap: {
                            currentIndex = index
                        }
                    )
                    .accessibilityHidden(true)
                }
            }
            .frame(width: CustomNumberPadView.width(forKeySize: keySize))
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(digitCount)-digit passcode")
            .accessibilityValue("\(passcode.count) of \(digitCount) digits entered")
            
            // Custom number pad
            CustomNumberPadView(
                onNumberTapped: { number in
                    handleNumberInput(number)
                },
                onBackspaceTapped: {
                    handleBackspace()
                },
                onHelpTapped: onHelpTapped
            )
        }
        .onAppear {
            currentIndex = 0
        }
        .onChange(of: passcode) { _, newValue in
            // Update digits when passcode changes externally
            if newValue.isEmpty {
                digits = Array(repeating: "", count: digitCount)
                currentIndex = 0
            }
        }
    }
    
    private func handleNumberInput(_ number: String) {
        guard currentIndex < digitCount else { return }
        
        // Set the digit at current position
        digits[currentIndex] = number
        
        // Update the bound passcode
        passcode = digits.joined()
        
        // Move to next position if not at the end
        if currentIndex < digitCount - 1 {
            currentIndex += 1
        }
    }
    
    private func handleBackspace() {
        // If current position has a digit, clear it
        if currentIndex < digitCount && !digits[currentIndex].isEmpty {
            digits[currentIndex] = ""
        } else if currentIndex > 0 {
            // Move back and clear the previous digit
            currentIndex -= 1
            digits[currentIndex] = ""
        }
        
        // Update the bound passcode
        passcode = digits.joined()
    }
}

struct DigitDisplay: View {
    let digit: String
    let isActive: Bool
    let onTap: () -> Void
    @ScaledMetric(relativeTo: .body) private var fieldHeight: CGFloat = 58
    
    var body: some View {
        Button(action: onTap) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color(.secondarySystemGroupedBackground))
                    .shadow(color: .black.opacity(0.04), radius: 4, y: 1)
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(
                        isActive ? KeepshireTheme.accent : Color(.separator).opacity(0.4),
                        lineWidth: isActive ? 2 : 0.5
                    )
                
                if !digit.isEmpty {
                    Circle()
                        .fill(KeepshireTheme.actionGradient)
                        .frame(width: 14, height: 14)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: min(fieldHeight, 76))
            .animation(.smooth(duration: 0.18), value: digit.isEmpty)
            .animation(.smooth(duration: 0.18), value: isActive)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    VStack(spacing: 30) {
        Text("4-Digit Passcode")
            .font(.title2)
        
        OTPStylePasscodeView(digitCount: 4, passcode: .constant(""))
        
        Text("6-Digit Passcode")
            .font(.title2)
        
        OTPStylePasscodeView(digitCount: 6, passcode: .constant(""))
    }
    .padding()
} 
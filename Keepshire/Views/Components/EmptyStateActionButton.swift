import SwiftUI

struct EmptyStateActionButton: View {
    let action: EmptyStateAction

    /// Uses the app's standard buttons so empty states match every other screen.
    var body: some View {
        switch action.style {
        case .primary:
            Button(action: action.action) { label }
                .buttonStyle(KeepshirePrimaryButtonStyle())
        case .secondary, .outline:
            Button(action: action.action) { label }
                .buttonStyle(KeepshireSecondaryButtonStyle())
        case .link:
            Button(action: action.action) { label }
                .font(.system(.subheadline, design: .rounded, weight: .semibold))
                .foregroundColor(KeepshireTheme.accent)
        case .custom(let backgroundColor, let foregroundColor):
            Button(action: action.action) { label }
                .buttonStyle(KeepshireSecondaryButtonStyle(tint: foregroundColor))
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(backgroundColor)
                )
        }
    }

    @ViewBuilder
    private var label: some View {
        if let icon = action.icon {
            Label(action.title, systemImage: icon)
        } else {
            Text(action.title)
        }
    }
}

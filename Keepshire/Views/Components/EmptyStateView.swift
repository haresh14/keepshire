import SwiftUI

struct EmptyStateView: View {
    private enum Layout {
        static let actionsSpacing: CGFloat = 12
        static let additionalMessageTopPadding: CGFloat = 2
        static let iconSize: CGFloat = 72
        static let maximumWidth: CGFloat = 420
        static let actionsWidth: CGFloat = 280
        static let hiddenScale: CGFloat = 0.96
        static let hiddenOffset: CGFloat = 12
    }

    let configuration: EmptyStateConfiguration
    @State private var isVisible = false

    init(_ configuration: EmptyStateConfiguration) {
        self.configuration = configuration
    }

    /// Every empty state uses the same hero as the auth screens and Trash: a
    /// gradient icon tile, a rounded title, and a secondary subtitle, centred.
    var body: some View {
        VStack(spacing: 24) {
            VStack(spacing: 16) {
                icon
                VStack(spacing: 8) {
                    Text(configuration.title)
                        .font(.system(.title2, design: .rounded, weight: .bold))
                        .foregroundColor(.primary)
                    if let subtitle = configuration.subtitle {
                        Text(subtitle)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    if let additionalMessage = configuration.additionalMessage {
                        Text(additionalMessage)
                            .font(.footnote)
                            .foregroundColor(.secondary)
                            .padding(.top, Layout.additionalMessageTopPadding)
                    }
                }
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            }

            actions
        }
        .frame(maxWidth: min(configuration.maxWidth ?? Layout.maximumWidth, Layout.maximumWidth))
        .padding(.horizontal, 32)
        .padding(.vertical, 24)
        .opacity(isVisible ? 1 : 0)
        .scaleEffect(isVisible ? 1 : Layout.hiddenScale)
        .offset(y: isVisible ? 0 : Layout.hiddenOffset)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear(perform: reveal)
    }

    @ViewBuilder
    private var icon: some View {
        if let customIcon = configuration.customIcon {
            customIcon
        } else if let iconName = configuration.iconName {
            KeepshireIconTile(systemName: iconName, size: Layout.iconSize, filled: true)
                .shadow(color: KeepshireTheme.glowTeal.opacity(0.35), radius: 16, y: 8)
        }
    }

    @ViewBuilder
    private var actions: some View {
        if configuration.primaryAction != nil || configuration.secondaryAction != nil {
            VStack(spacing: Layout.actionsSpacing) {
                if let primaryAction = configuration.primaryAction {
                    EmptyStateActionButton(action: primaryAction)
                }
                if let secondaryAction = configuration.secondaryAction {
                    EmptyStateActionButton(action: secondaryAction)
                }
            }
            .frame(maxWidth: Layout.actionsWidth)
        }
    }

    private func reveal() {
        guard configuration.animation.enabled else {
            isVisible = true
            return
        }

        withAnimation(
            .easeOut(duration: configuration.animation.duration)
                .delay(configuration.animation.delay)
        ) {
            isVisible = true
        }
    }
}

extension View {
    func emptyState(
        _ isEmpty: Bool,
        configuration: EmptyStateConfiguration
    ) -> some View {
        ZStack {
            self.opacity(isEmpty ? 0 : 1)
            if isEmpty {
                EmptyStateView(configuration)
            }
        }
    }

    func emptyState<T>(
        for items: [T],
        configuration: EmptyStateConfiguration
    ) -> some View {
        emptyState(items.isEmpty, configuration: configuration)
    }
}

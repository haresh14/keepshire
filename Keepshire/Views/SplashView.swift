import SwiftUI

/// Animated splash shown once per cold launch.
///
/// It starts as an exact copy of the static launch screen (`UILaunchScreen`:
/// `LaunchBackground` colour with the 120 pt `AppLogo` centred), so the handoff
/// from the system launch image is seamless. The logo then pops, a brand ring
/// pulses out from it, and the wordmark rises in before the whole splash fades
/// away. With Reduce Motion on, it only cross-fades.
struct SplashView: View {
    let onFinished: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var logoScale: CGFloat = 1
    @State private var ringScale: CGFloat = 1
    @State private var ringOpacity: Double = 0
    @State private var wordmarkOpacity: Double = 0
    @State private var wordmarkOffset: CGFloat = 12
    @State private var opacity: Double = 1

    private static let logoSize: CGFloat = 120

    var body: some View {
        ZStack {
            Color("LaunchBackground")
                .ignoresSafeArea()

            Circle()
                .stroke(KeepshireTheme.brandGradient, lineWidth: 3)
                .frame(width: Self.logoSize, height: Self.logoSize)
                .scaleEffect(ringScale)
                .opacity(ringOpacity)

            Image("AppLogo")
                .resizable()
                .frame(width: Self.logoSize, height: Self.logoSize)
                .shadow(color: .black.opacity(0.12), radius: 12, y: 6)
                .scaleEffect(logoScale)
                .accessibilityHidden(true)

            Text(AppMetadata.displayName)
                .font(.system(.title, design: .rounded, weight: .bold))
                .foregroundStyle(KeepshireTheme.brandGradient)
                .opacity(wordmarkOpacity)
                .offset(y: Self.logoSize / 2 + 36 + wordmarkOffset)
        }
        .opacity(opacity)
        .allowsHitTesting(false)
        .accessibilityElement()
        .accessibilityLabel(AppMetadata.displayName)
        .task { await play() }
    }

    @MainActor
    private func play() async {
        if reduceMotion {
            withAnimation(.easeOut(duration: 0.25)) { wordmarkOpacity = 1 }
            try? await Task.sleep(for: .milliseconds(450))
            withAnimation(.easeOut(duration: 0.3)) { opacity = 0 }
            try? await Task.sleep(for: .milliseconds(300))
            onFinished()
            return
        }

        // Anticipation, then a springy pop.
        withAnimation(.easeIn(duration: 0.14)) { logoScale = 0.9 }
        try? await Task.sleep(for: .milliseconds(140))
        withAnimation(.spring(response: 0.42, dampingFraction: 0.55)) { logoScale = 1.06 }

        // Ring pulses outward from the logo edge.
        ringOpacity = 0.7
        withAnimation(.easeOut(duration: 0.75)) {
            ringScale = 2.1
            ringOpacity = 0
        }

        try? await Task.sleep(for: .milliseconds(160))
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
            wordmarkOpacity = 1
            wordmarkOffset = 0
        }

        try? await Task.sleep(for: .milliseconds(650))
        // Exit: the logo eases up slightly while everything fades.
        withAnimation(.easeInOut(duration: 0.35)) {
            logoScale = 1.18
            opacity = 0
        }
        try? await Task.sleep(for: .milliseconds(350))
        onFinished()
    }
}

#Preview {
    SplashView(onFinished: {})
}

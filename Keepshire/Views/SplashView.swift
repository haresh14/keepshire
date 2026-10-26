import SwiftUI

/// Animated splash shown once per cold launch.
///
/// The first frame is identical to the static launch screen (`UILaunchScreen`:
/// `LaunchBackground` deep teal with the 120 pt `AppLogo` centred), so the
/// handoff from the system launch image is invisible. A soft brand glow then
/// blooms behind the logo while it settles, the wordmark and tagline rise in,
/// and the splash exits with a zoom-through: the logo grows and fades as the
/// app appears. All curves are critically damped, so nothing bounces.
/// With Reduce Motion on, it only cross-fades.
struct SplashView: View {
    let onFinished: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var glowOpacity: Double = 0
    @State private var glowScale: CGFloat = 0.6
    @State private var logoScale: CGFloat = 1
    @State private var textOpacity: Double = 0
    @State private var textOffset: CGFloat = 10
    @State private var logoExitOpacity: Double = 1
    @State private var backgroundOpacity: Double = 1

    private static let logoSize: CGFloat = 120

    var body: some View {
        ZStack {
            KeepshireTheme.launchBackground
                .opacity(backgroundOpacity)
                .ignoresSafeArea()

            glow
                .opacity(glowOpacity * backgroundOpacity)

            Image("AppLogo")
                .resizable()
                .frame(width: Self.logoSize, height: Self.logoSize)
                .shadow(color: .black.opacity(0.3), radius: 18, y: 10)
                .scaleEffect(logoScale)
                .opacity(logoExitOpacity)
                .accessibilityHidden(true)

            VStack(spacing: 6) {
                Text(AppMetadata.displayName)
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text("Private. Encrypted. Yours.")
                    .font(.system(.subheadline, design: .rounded, weight: .medium))
                    .foregroundStyle(.white.opacity(0.7))
            }
            .opacity(textOpacity * backgroundOpacity)
            .offset(y: Self.logoSize / 2 + 56 + textOffset)
        }
        // Centre on the full screen, as the launch image does, so the logo does not jump.
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityElement()
        .accessibilityLabel(AppMetadata.displayName)
        .task { await play() }
    }

    /// Two blurred brand-coloured discs, offset so the glow reads teal-to-green.
    private var glow: some View {
        ZStack {
            Circle()
                .fill(KeepshireTheme.glowTeal)
                .frame(width: 260, height: 260)
                .offset(x: -40, y: -30)
            Circle()
                .fill(KeepshireTheme.glowGreen)
                .frame(width: 220, height: 220)
                .offset(x: 50, y: 40)
        }
        .blur(radius: 70)
        .scaleEffect(glowScale)
    }

    @MainActor
    private func play() async {
        // Let the first frame (identical to the launch image) land before moving.
        try? await Task.sleep(for: .milliseconds(120))

        if reduceMotion {
            withAnimation(.easeOut(duration: 0.3)) {
                glowOpacity = 0.5
                textOpacity = 1
                textOffset = 0
            }
            try? await Task.sleep(for: .milliseconds(700))
            withAnimation(.easeInOut(duration: 0.35)) {
                logoExitOpacity = 0
                backgroundOpacity = 0
            }
            try? await Task.sleep(for: .milliseconds(350))
            onFinished()
            return
        }

        // Glow blooms while the logo settles a touch larger.
        withAnimation(.smooth(duration: 0.9)) {
            glowOpacity = 0.55
            glowScale = 1.15
        }
        withAnimation(.smooth(duration: 0.7)) {
            logoScale = 1.06
        }

        try? await Task.sleep(for: .milliseconds(250))
        withAnimation(.smooth(duration: 0.55)) {
            textOpacity = 1
            textOffset = 0
        }

        try? await Task.sleep(for: .milliseconds(800))

        // Zoom-through exit: text and background fade, the logo grows and dissolves.
        withAnimation(.smooth(duration: 0.3)) {
            textOpacity = 0
        }
        withAnimation(.smooth(duration: 0.5)) {
            logoScale = 1.9
            logoExitOpacity = 0
        }
        withAnimation(.smooth(duration: 0.45).delay(0.08)) {
            backgroundOpacity = 0
        }
        try? await Task.sleep(for: .milliseconds(550))
        onFinished()
    }
}

#Preview {
    SplashView(onFinished: {})
}

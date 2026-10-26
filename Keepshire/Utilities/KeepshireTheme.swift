import SwiftUI

/// Brand palette sampled directly from the app icon so the UI and the icon read
/// as one product.
///
/// `accent` and `success` live in the asset catalog because the accent is also
/// the target's global accent colour and has to resolve outside SwiftUI. The
/// gradient stops below are the raw icon artwork colours: they always sit on a
/// brand-coloured surface, so they do not vary by appearance.
enum KeepshireTheme {
    /// Primary action colour. Tabs, buttons, links, selection, folders, progress.
    static let accent = Color("AccentColor")

    /// Reserved for success states: unlocked, imported, protected.
    static let success = Color("BrandGreen")

    // Icon artwork stops.
    private static let iconTeal = Color(red: 0x07 / 255, green: 0x9A / 255, blue: 0xAC / 255)
    private static let iconMint = Color(red: 0x2C / 255, green: 0xDD / 255, blue: 0xAE / 255)
    private static let iconGreen = Color(red: 0x76 / 255, green: 0xD5 / 255, blue: 0x5C / 255)

    /// The icon's teal-to-green sweep. Reserved for authentication, the privacy
    /// overlay, and branded empty states so the rest of the app stays neutral.
    static let brandGradient = LinearGradient(
        colors: [iconTeal, iconMint, iconGreen],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    /// A wash of the same sweep, for backgrounds that sit behind ordinary text.
    static let brandWash = LinearGradient(
        colors: [iconTeal.opacity(0.12), iconGreen.opacity(0.12)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    /// Deep teal behind the launch screen and splash (`LaunchBackground` in the
    /// asset catalog, so the static launch image and the splash match exactly).
    static let launchBackground = Color("LaunchBackground")

    /// Darker cut of the sweep for filled buttons and selected tiles. Dark enough
    /// that white text stays readable in light and dark mode.
    static let actionGradient = LinearGradient(
        colors: [
            Color(red: 0x00 / 255, green: 0x6E / 255, blue: 0x8A / 255),
            Color(red: 0x0A / 255, green: 0x86 / 255, blue: 0x6E / 255)
        ],
        startPoint: .leading,
        endPoint: .trailing
    )

    /// Glow colours for the splash and setup hero.
    static let glowTeal = iconTeal
    static let glowGreen = iconGreen

    /// Opaque, dark variant of the sweep. Used for the privacy cover, which must
    /// hide the vault completely while still looking like Keepshire.
    static let brandScrim = LinearGradient(
        colors: [
            Color(red: 0x03 / 255, green: 0x2A / 255, blue: 0x30 / 255),
            Color(red: 0x14 / 255, green: 0x30 / 255, blue: 0x18 / 255)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

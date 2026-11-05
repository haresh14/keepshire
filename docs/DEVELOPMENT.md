# Development

Set up, build, run, and change Keepshire.

## Requirements

| | |
|---|---|
| Xcode | Current release (the project builds with the iOS 27 SDK) |
| Minimum iOS | 18.5 (project, app, and unit-test targets) |
| Devices | iPhone and iPad |
| Swift language mode | 5.0 |
| Dependencies | None (no Swift packages, no CocoaPods) |
| Project | `Keepshire.xcodeproj`, scheme `Keepshire` |

| Target | Bundle ID |
|---|---|
| App | `dev.haresh.keepshire` |
| Share Extension | `dev.haresh.keepshire.share` |
| Unit tests | `dev.haresh.keepshire.tests` |
| UI tests | `dev.haresh.keepshire.uitests` |

App Group: `group.dev.haresh.keepshire`. Team: `AYL8H487NP`, automatic signing.

`dev.haresh.keepshire` is a different app from any old `com.haresh.FileVault` install; nothing migrates between them.

## Run it

1. Open `Keepshire.xcodeproj`.
2. Pick a simulator, or a device with signing set up (below).
3. Press **⌘R**.

On a simulator, Face ID is under **Features → Face ID** (Enrolled, Matching Face, Non-matching Face).

### Run on your iPhone

1. In **Signing & Capabilities**, set your Team on both **Keepshire** and **KeepshireShare**, with "Automatically manage signing" on. Confirm the App Groups capability lists `group.dev.haresh.keepshire`.
2. Turn on Developer Mode on the iPhone (Settings → Privacy & Security) and trust the Mac.
3. Select the device and press **⌘R**. If iOS asks, trust the developer in Settings → General → VPN & Device Management.

With a free Apple ID, an installed build expires after 7 days.

## Install from the command line

[`install-on-device.sh`](../install-on-device.sh) builds the Debug app and installs it with `xcrun devicectl`. It does not launch it.

```bash
./install-on-device.sh
```

```bash
./install-on-device.sh <UDID>
```

The first form picks the first paired physical iPhone. List devices with `xcrun devicectl list devices`. Run it by hand once to answer any signing prompts; it passes `-allowProvisioningUpdates`. Build output goes to `build/DerivedData` (git-ignored). After one cable pairing, the phone can be reached over Wi-Fi.

### Install every weekday at 11 AM (optional)

Use a LaunchAgent, not cron: it runs in your login session, so signing can reach the keychain, and a run missed during sleep happens on wake. Save as `~/Library/LaunchAgents/com.keepshire.install-on-device.plist`, replacing the path and `<user>`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.keepshire.install-on-device</string>
    <key>ProgramArguments</key>
    <array>
        <string>/path/to/Keepshire/install-on-device.sh</string>
    </array>
    <key>StartCalendarInterval</key>
    <array>
        <dict><key>Weekday</key><integer>1</integer><key>Hour</key><integer>11</integer><key>Minute</key><integer>0</integer></dict>
        <dict><key>Weekday</key><integer>2</integer><key>Hour</key><integer>11</integer><key>Minute</key><integer>0</integer></dict>
        <dict><key>Weekday</key><integer>3</integer><key>Hour</key><integer>11</integer><key>Minute</key><integer>0</integer></dict>
        <dict><key>Weekday</key><integer>4</integer><key>Hour</key><integer>11</integer><key>Minute</key><integer>0</integer></dict>
        <dict><key>Weekday</key><integer>5</integer><key>Hour</key><integer>11</integer><key>Minute</key><integer>0</integer></dict>
    </array>
    <key>StandardOutPath</key>
    <string>/Users/<user>/Library/Logs/keepshire-install.log</string>
    <key>StandardErrorPath</key>
    <string>/Users/<user>/Library/Logs/keepshire-install.log</string>
</dict>
</plist>
```

| Task | Command |
|---|---|
| Load | `launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.keepshire.install-on-device.plist` |
| Run now | `launchctl kickstart gui/$(id -u)/com.keepshire.install-on-device` |
| Status | `launchctl print gui/$(id -u)/com.keepshire.install-on-device` |
| Log | `tail -f ~/Library/Logs/keepshire-install.log` |
| Unload (before loading an edited plist) | `launchctl bootout gui/$(id -u)/com.keepshire.install-on-device` |

Check it works: `launchctl list | grep keepshire` prints `-  0  com.keepshire.install-on-device`; `launchctl print` lists five calendar triggers at 11:00 for weekdays 1–5; the log ends each run with `Done`. At 11:00 you must be logged in (a locked screen is fine) and the iPhone reachable by cable or Wi-Fi.

| Problem | Fix |
|---|---|
| `Bootstrap failed: 5: Input/output error` | Already loaded. `bootout`, then `bootstrap` again. |
| `Operation not permitted` in the log | Give `/bin/zsh` Full Disk Access (System Settings → Privacy & Security). |
| `does not contain a scheme named "Keepshire"` | Build from `Keepshire.xcodeproj`, not a stray `.xcworkspace`. |

## Project configuration

| Setting | Value |
|---|---|
| Info.plist | Checked in at `Keepshire/Info.plist` (`GENERATE_INFOPLIST_FILE = NO`) |
| Display name | `Keepshire` |
| `NSFaceIDUsageDescription` | `Use Face ID to unlock Keepshire` |
| `NSLocalNetworkUsageDescription` | `Keepshire uses the local network so you can upload files from a browser on the same Wi-Fi.` |
| Photo library usage text | Not needed: the photo picker runs outside the app |
| Launch screen | `UILaunchScreen` with color `LaunchBackground` and image `AppLogo`; light status bar. Required as an explicit dictionary with the iOS 27 SDK. |
| Scenes | One `WindowGroup`; multiple windows disabled |
| iPad orientations | All four (required for iPad multitasking) |
| Background modes | None. Running uploads use a finite background task. |
| Bonjour | Not advertised; no `NSBonjourServices` |
| Entitlements | App Groups only, on app and extension. No iCloud, push, or associated domains. |
| Privacy manifest | `Keepshire/PrivacyInfo.xcprivacy`: UserDefaults `CA92.1`, file timestamps `C617.1` (storage total); no tracking, no collected data |
| Encryption export key | Not set in Info.plist; see [RELEASE.md](RELEASE.md#export-compliance) |
| Debug-only code | The Settings Developer section and `--ui-testing` launch arguments compile only in Debug |

Apple frameworks used: SwiftUI, UIKit, Core Data, CryptoKit, CommonCrypto, Security, LocalAuthentication, PhotosUI, Photos, UniformTypeIdentifiers, AVFoundation, AVKit, QuickLook, PDFKit, Network, UserNotifications, CoreMotion, Core Image, Combine, MetricKit.

## Working on the code

- **Structure.** MVVM: views stay thin, logic lives in view models, managers, and services. See [ARCHITECTURE.md](ARCHITECTURE.md).
- **New files.** Folders are synchronized with the project; a new `.swift` file in `Keepshire/` joins the target automatically.
- **Dependencies.** Add a protocol in `Dependencies/DependencyContainer.swift` for anything a test needs to fake.
- **Security-sensitive code.** Anything touching keys, the Keychain, or file encryption needs unit tests for success, wrong input, and a failed Keychain read or write. Never treat an unreadable Keychain as empty.
- **Strings.** English source strings in `Localizable.xcstrings` (app) and `KeepshireShare/Localizable.xcstrings`. Xcode adds new strings when you build in the IDE.
- **Logging.** Use `VaultLog`. Release builds must not log file names, paths, or security state.
- **Privacy manifest.** Re-check it whenever you add a required-reason API.
- **Notifications permission.** Ask only when Web Upload first starts, never at launch or unlock.
- **Docs.** When behavior changes, update the matching file in `docs/` in the same change. Docs describe the app as it is now, in present tense.

## Upgrading Xcode or the iOS SDK

Compile with the new SDK without changing behavior.

1. Keep the minimum iOS at 18.5 unless the product decides otherwise.
2. Keep Swift 5 language mode; do not turn on complete concurrency checking as part of an SDK bump.
3. Replace an API only when the SDK requires it. Do not change Core Data, encryption, or the web server during a bump.
4. Run the unit tests serially and the full checklist in [TESTING.md](TESTING.md).

APIs already adjusted for iOS 27:

| API | Approach |
|---|---|
| `NavigationView` | `NavigationStack` |
| `.accentColor` | `.tint` |
| `presentationMode` | `@Environment(\.dismiss)` |
| One-parameter `.onChange` | Two-parameter form |
| Context-menu icons hidden on iPadOS 27 | `.labelStyle(.titleAndIcon)` |
| `UIScreen.main.isCaptured` | The scene's `screen.isCaptured` |
| `LABiometryType.opticID` | Treated as no biometrics |
| Launch screen | Explicit `UILaunchScreen` dictionary |

Remaining build warnings are deprecations (`copyCGImage`, `tracks(withMediaType:)`, `duration`, `shouldUseExtendedBackgroundIdleMode`) and do not block release.

## Troubleshooting

| Problem | Fix |
|---|---|
| "No such module" or odd build errors | Product → Clean Build Folder (⇧⌘K), then build again |
| No simulators | Xcode → Settings → Components |
| Unit tests crash or hang in parallel | Run serially with `-parallel-testing-enabled NO` |
| App shows setup although a vault existed | The Keychain was cleared (new device, simulator reset). The old files cannot be opened without that Keychain. |
| Screenshots of the app are black | Screenshot Protection is on (Settings → Advanced Security) |
| Screen recording is black | Screen Recording Protection is on |

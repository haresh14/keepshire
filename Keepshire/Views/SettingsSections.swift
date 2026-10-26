import SwiftUI

/// Settings row title with a coloured icon tile, in the style of iOS Settings.
struct SettingsRowLabel: View {
    let title: String
    let systemImage: String
    var tint: Color = KeepshireTheme.accent

    var body: some View {
        HStack(spacing: 12) {
            KeepshireIconTile(systemName: systemImage, tint: tint, size: 30)
            Text(title)
        }
    }
}

struct SettingsSecuritySection: View {
    @Binding var screenshotProtection: Bool
    @Binding var recordingProtection: Bool
    @Binding var shakeToLock: Bool
    @Binding var flipToLock: Bool
    let updateScreenshotProtection: (Bool) -> Void
    let updateRecordingProtection: (Bool) -> Void
    let updateShakeToLock: (Bool) -> Void
    let updateFlipToLock: (Bool) -> Void

    var body: some View {
        Section("Advanced Security") {
            Toggle(isOn: $screenshotProtection) {
                SettingsRowLabel(title: "Screenshot Protection", systemImage: "camera.viewfinder", tint: .indigo)
            }
                .accessibilityIdentifier("settings.screenshotProtection")
                .onChange(of: screenshotProtection) { _, value in updateScreenshotProtection(value) }
            Toggle(isOn: $recordingProtection) {
                SettingsRowLabel(title: "Screen Recording Protection", systemImage: "record.circle", tint: .red)
            }
                .accessibilityIdentifier("settings.recordingProtection")
                .onChange(of: recordingProtection) { _, value in updateRecordingProtection(value) }
            Toggle(isOn: $shakeToLock) {
                SettingsRowLabel(title: "Shake to Lock", systemImage: "iphone.radiowaves.left.and.right", tint: .orange)
            }
                .accessibilityIdentifier("settings.shakeToLock")
                .onChange(of: shakeToLock) { _, value in updateShakeToLock(value) }
            Toggle(isOn: $flipToLock) {
                SettingsRowLabel(title: "Flip to Lock", systemImage: "arrow.uturn.down", tint: .teal)
            }
                .accessibilityIdentifier("settings.flipToLock")
                .onChange(of: flipToLock) { _, value in updateFlipToLock(value) }
            VStack(alignment: .leading, spacing: 5) {
                Text("Enhanced Protection").font(.caption).foregroundColor(.secondary)
                Text("• Screenshots: the vault stays on screen; Photos gets a blank image\n• Screen recording: a black cover while a recording is in progress\n• Shake to Lock: locks the app when the device is shaken vigorously\n• Flip to Lock: locks the app when the device is flipped face-down")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
    }
}

struct SettingsAuthenticationSection: View {
    let currentAuthType: AuthenticationType
    let isFakePasswordSet: Bool
    @Binding var lockTimeout: Int
    @Binding var biometricEnabled: Bool
    let showChangeAuthentication: () -> Void
    let showFakePasswordSetup: () -> Void
    let removeFakePassword: () -> Void
    let updateLockTimeout: (Int) -> Void
    let updateBiometric: (Bool) -> Void

    var body: some View {
        Section("Security") {
            LabeledContent {
                Text(currentAuthType.displayName)
            } label: {
                SettingsRowLabel(title: "Current Method", systemImage: "lock.fill", tint: .blue)
            }
            Button(action: showChangeAuthentication) {
                HStack {
                    SettingsRowLabel(title: "Change Authentication", systemImage: "key.fill", tint: .orange)
                    Spacer()
                    Image(systemName: "chevron.right").foregroundColor(.secondary).font(.caption)
                }
            }
            .foregroundColor(.primary)
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    SettingsRowLabel(title: "Fake Password", systemImage: "theatermasks.fill", tint: .purple)
                    Spacer()
                    Text(isFakePasswordSet ? "Set" : "Not Set")
                        .foregroundColor(isFakePasswordSet ? KeepshireTheme.success : .secondary)
                        .font(.caption)
                }
                Text("Create a decoy password that shows an empty vault when used")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .padding(.leading, 42)
            }
            Button(action: showFakePasswordSetup) {
                HStack {
                    SettingsRowLabel(
                        title: isFakePasswordSet ? "Change Fake Password" : "Set Fake Password",
                        systemImage: "pencil",
                        tint: .purple
                    )
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundColor(.secondary)
                        .font(.caption)
                }
            }
            .foregroundColor(.primary)
            if isFakePasswordSet {
                Button("Remove Fake Password", role: .destructive, action: removeFakePassword)
            }
            Picker(selection: $lockTimeout) {
                ForEach(KeychainManager.LockTimeout.allCases, id: \.self) { timeout in
                    Text(timeout.displayName).tag(timeout.rawValue)
                }
            } label: {
                SettingsRowLabel(title: "Auto-Lock", systemImage: "timer", tint: .teal)
            }
            .accessibilityIdentifier("settings.autoLock")
            .onChange(of: lockTimeout) { _, value in updateLockTimeout(value) }
            Toggle(isOn: $biometricEnabled) {
                SettingsRowLabel(title: "Enable Biometric Authentication", systemImage: "faceid", tint: .green)
            }
                .accessibilityIdentifier("settings.biometric")
                .onChange(of: biometricEnabled) { _, value in updateBiometric(value) }
            biometricStatus
        }
    }

    private var biometricStatus: some View {
        let isAvailable = BiometricAuthManager.shared.canUseBiometrics()
        let isFaceID = BiometricAuthManager.shared.biometricType() == .faceID
        return HStack {
            Image(systemName: isAvailable ? (isFaceID ? "faceid" : "touchid") : "exclamationmark.circle")
                .foregroundColor(isAvailable ? KeepshireTheme.success : .orange)
            Text(isAvailable ? "\(isFaceID ? "Face ID" : "Touch ID") Available" : "Biometric authentication not available")
                .foregroundColor(.secondary)
                .font(.caption)
        }
    }
}

struct SettingsTrashDataSections: View {
    @Binding var trashEnabled: Bool
    let trashItemCount: Int
    let fileCount: Int
    let formattedUsedSpace: String
    let updateTrashEnabled: (Bool) -> Void
    var openTrash: (() -> Void)? = nil

    var body: some View {
        Group {
            Section("Trash") {
                Toggle(isOn: $trashEnabled) {
                    SettingsRowLabel(title: "Enable Trash", systemImage: "trash.fill", tint: .red)
                }
                    .accessibilityIdentifier("settings.trash")
                    .onChange(of: trashEnabled) { _, value in updateTrashEnabled(value) }
                if trashEnabled {
                    if let openTrash {
                        Button(action: openTrash) {
                            HStack {
                                SettingsRowLabel(title: "View Trash", systemImage: "tray.full.fill", tint: .gray)
                                Spacer()
                                if trashItemCount > 0 {
                                    Text("\(trashItemCount)").foregroundColor(.secondary)
                                }
                            }
                        }
                        .foregroundColor(.primary)
                    } else {
                        NavigationLink(destination: TrashView()) {
                            HStack {
                                SettingsRowLabel(title: "View Trash", systemImage: "tray.full.fill", tint: .gray)
                                Spacer()
                                if trashItemCount > 0 {
                                    Text("\(trashItemCount)").foregroundColor(.secondary)
                                }
                            }
                        }
                        .foregroundColor(.primary)
                    }
                    Text("Deleted files are moved to trash instead of being permanently deleted.")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            Section("Disk") {
                LabeledContent {
                    Text("\(fileCount)")
                } label: {
                    SettingsRowLabel(title: "Total Files", systemImage: "doc.on.doc.fill", tint: .blue)
                }
                LabeledContent {
                    Text(formattedUsedSpace)
                } label: {
                    SettingsRowLabel(title: "Total Size", systemImage: "internaldrive.fill", tint: .gray)
                }
            }
        }
    }
}

struct SettingsWebBackgroundSection: View {
    let lockTimeoutDisplayName: String
    let lockBehaviorDescription: String

    var body: some View {
        Section("Lock Behavior") {
            VStack(alignment: .leading, spacing: 5) {
                Text("Current Setting: \(lockTimeoutDisplayName)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(lockBehaviorDescription)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
    }
}

#if DEBUG
struct SettingsDebugSection: View {
    let completeReset: () -> Void
    let simulateFirstLaunch: () -> Void
    let deleteAllFiles: () -> Void

    var body: some View {
        Section("Developer Options") {
            Button(action: completeReset) {
                Label("Complete App Reset", systemImage: "exclamationmark.triangle").foregroundColor(.red)
            }
            Button(action: simulateFirstLaunch) {
                Label("Simulate First Launch Cleanup", systemImage: "arrow.clockwise").foregroundColor(.orange)
            }
            Button(action: deleteAllFiles) {
                Label("Delete All Files & Folders", systemImage: "trash.fill").foregroundColor(.orange)
            }
        }
    }
}
#endif

# Testing

Automated tests run on every change. The manual checklist runs before each release and after an SDK upgrade.

## Automated tests

| Target | Framework | What it covers |
|---|---|---|
| `KeepshireTests` | Swift Testing | Vault key, passcode change, recovery key, Face ID copy, lockout, Keychain, PBKDF2 and AES-GCM, chunked files, thumbnails, trash, temporary share files, legacy vault migration, authentication flow, Share inbox import, view models, web server helpers, dependency container, empty states, video player lifecycle |
| `KeepshireUITests` | XCTest | First launch, tabs, decoy restrictions, add controls, launch. `AppStoreScreenshotTests` runs only when `SCREENSHOT_DIR` is set. |

Run unit tests **serially**; parallel clones can crash the test host.

```bash
xcodebuild -project Keepshire.xcodeproj -scheme Keepshire -destination 'platform=iOS Simulator,name=iPhone 18 Pro' test -only-testing:KeepshireTests -parallel-testing-enabled NO
```

UI smoke tests, on an iPhone and an iPad simulator:

```bash
xcodebuild -project Keepshire.xcodeproj -scheme Keepshire -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M5)' test -only-testing:KeepshireUITests -parallel-testing-enabled NO
```

In Xcode, **⌘U** runs the scheme's tests.

UI tests launch with `--ui-testing` (Debug only), which resets the app, creates a vault with passcode `1234`, turns off Face ID, sets auto-lock to Never, and skips the recovery key offer. Extra arguments: `--ui-testing-first-launch` (start at setup), `--ui-testing-fake-login` (adds decoy `9876`), `--ui-testing-recovery-offer` (keep the offer).

Tests use isolated Keychain services and in-memory stores (`IsolatedTestDependencies`, `InMemoryVaultKeyDerivationStore`), so they never touch a real vault.

## Manual checklist

Use a physical iPhone where Face ID, the camera roll, or another device is involved.

### First launch and setup
- [ ] Fresh install shows the logo on deep teal, then the splash, then **Secure your vault**, with no jump at the handoff.
- [ ] 6-digit is preselected and marked Recommended; 4-digit says it is weaker; the warning about forgotten passcodes is visible.
- [ ] 4-digit and 6-digit need the exact length twice; password needs 6+ characters twice.
- [ ] After setup, the recovery key offer appears; Not Now goes to the five tabs.
- [ ] A saved lock type with no vault in the Keychain (simulator Keychain reset) shows setup, not a lock screen.

### Unlock and lockout
- [ ] Correct passcode opens the vault; wrong one shakes, clears, and shows a message.
- [ ] After 5 wrong tries a countdown appears and survives relaunch.
- [ ] Face ID runs on the lock screen when enabled; cancel shows the keypad; success opens the real vault.
- [ ] Auto-lock: Immediately locks on return; 30 s stays open before 30 s and locks after; Never stays open.
- [ ] App Switcher shows the opaque cover, never vault content.

### Recovery key
- [ ] Create: key shows once in two lines of three groups; Copy and Save work; typing the last 4 characters (any case, O for 0) turns it on.
- [ ] Settings → Recovery Key shows On; the screen offers Create New Key and Turn Off (with confirmation).
- [ ] Lock screen shows "Forgot passcode?" only when a key exists.
- [ ] Wrong length says a key has 24 characters and does not count as a guess; a wrong key counts toward the lockout.
- [ ] The right key (lowercase, spaces allowed) → choose any lock → vault opens; the old passcode no longer works; the key still works.

### Change lock
- [ ] Settings → Change Authentication: current credential, new type, new credential; files still open with the new one only.
- [ ] Face ID and the recovery key still work afterwards.
- [ ] The decoy is removed and the app offers to set a new one.

### Decoy vault
- [ ] Setting the real passcode as the decoy is refused and returns to the first entry.
- [ ] The decoy opens an empty vault: no Add, no folders, no Web Upload, Settings shows About only, no recovery key offer.
- [ ] Recovery that keeps the same lock type keeps the decoy working.

### Files and folders
- [ ] Import up to 50 photos and videos; import PDF, text, Office, zip, and audio from Files.
- [ ] Duplicates are skipped; name clashes become `name (n).ext`; files over 2 GB are refused; a 1.9 GB video imports without a crash.
- [ ] Nested folders: create, rename, move (not into itself), delete with trash on and off, swipe to delete.
- [ ] Search in Gallery, Categories, and Folders (files and child folders); Folder search field shows on first appearance.
- [ ] Sort by every option, including Duration (non-videos first ascending, ties by size); videos show their length.
- [ ] Multi-select: Select All, Favorite, Share, Move, Delete.
- [ ] Category counts and lists are right.
- [ ] Trash: restore, delete forever, empty, and the "Empty Trash & Disable" prompt.

### Viewing
- [ ] Photos: swipe, pinch, pan, double-tap.
- [ ] Videos: autoplay, play/pause, scrub, ±15 s, speed, zoom.
- [ ] Audio plays and seeks; PDFs and other documents open.
- [ ] Share produces a usable file; after cancel and lock, nothing is left in `tmp/keepshire-share/`.

### Share Extension
- [ ] Share an image, video, PDF, and other file to Keepshire.
- [ ] Before unlock, files wait in the App Group inbox; a decoy unlock leaves them there.
- [ ] A real unlock imports them into the root folder and empties the inbox; returning to an already-unlocked vault also imports.
- [ ] Force-quitting during import does not lose a pending file.

### Web Upload
- [ ] Start Server shows the https address, QR code, pairing code, and fingerprint; first start asks for notification permission.
- [ ] From another device: accept the certificate warning, pair, upload small and >100 MB files.
- [ ] Drag files or a folder onto the explorer: overlay names the folder; folders keep their structure.
- [ ] Downloads appear only after Allow Downloads with Face ID or the passcode; Download Selected returns `Keepshire Selection.zip`.
- [ ] Lock the phone: the browser says to unlock the iPhone; after unlock, the retry works.
- [ ] Banners in the app while on screen; a system notification when not.
- [ ] The decoy cannot start the server.

### Device protections
- [ ] Screenshot protection on: the screen looks normal, the saved screenshot is blank (sheets and previews too), one alert.
- [ ] Off: screenshots include the vault, no alert. Both toggles keep their state after relaunch.
- [ ] Screen recording cover stays up across app switches and when recording was already running at launch.
- [ ] Shake to lock and flip to lock, when enabled.

### Encryption checks (simulator)
- [ ] Files in `Documents/Vault/` have UUID names and are not readable; `Documents/Thumbnails/*.thumb` are not JPEGs.
- [ ] In `Keepshire.sqlite`, `fileName` and folder `name` are empty and `sealedMetadata` is filled.
- [ ] Renaming changes the name in the app, not the file name on disk.

### iPad, accessibility, localization
- [ ] iPad: Folder and Category sidebars, full-width Gallery and Trash, Settings sidebar; every file opens full screen; all orientations; Split View and Stage Manager fall back to phone layout; one window only.
- [ ] VoiceOver announces passcode progress, not digits.
- [ ] Largest Dynamic Type keeps the keypad and buttons usable.
- [ ] Right-to-left pseudolanguage: layout mirrors, keypad stays 1–9.

### Settings and release checks
- [ ] About shows the built version and build; Privacy and Support open the live pages.
- [ ] Debug Developer section: Complete App Reset returns to setup with empty vault folders; Delete All Files & Folders keeps the passcode.
- [ ] Home screen, Face ID prompt, and local-network prompt say Keepshire.
- [ ] Archive has the privacy manifest and no `ITSAppUsesNonExemptEncryption` key (or the key with its code).
- [ ] A Release run logs no file names, paths, or security state.
- [ ] A vault from the previous release opens with the same passcode after updating.

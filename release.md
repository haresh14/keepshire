# Releasing Keepshire to the App Store

This is the end-to-end guide for shipping Keepshire 1.0 (and later versions) to the App Store. Everything that can live in the repo is in [`release/`](release/). Everything that needs your Apple ID is listed below as a step you do in a browser or in Xcode.

Steps marked **(one time)** are only needed for the first release.

---

## 1. Release facts

| Field | Value |
|---|---|
| App Store name (30 max) | `Keepshire: Private Photo Vault` |
| Home screen name | `Keepshire` |
| Subtitle (30 max) | `Hide photos, videos & files` |
| Bundle ID (app) | `dev.haresh.keepshire` |
| Bundle ID (share extension) | `dev.haresh.keepshire.share` |
| App Group | `group.dev.haresh.keepshire` |
| Team ID | `AYL8H487NP` |
| Version / build | `1.0` / `1` |
| Minimum iOS | 18.5 |
| Devices | iPhone and iPad (iPad screenshots are required) |
| SKU | `keepshire` |
| Primary language | English (U.S.) |
| Primary / secondary category | Utilities / Photo & Video |
| Price | Free (no in-app purchases) |
| Age rating | 4+ (see [§10](#10-age-rating)) |
| Privacy policy URL | https://keepshire.haresh.dev/privacy |
| Support URL | https://keepshire.haresh.dev/support |
| Marketing URL | https://keepshire.haresh.dev |
| Support email | hello@haresh.dev |
| Copyright | `2026 Haresh Godhani` |
| Export compliance | `ITSAppUsesNonExemptEncryption = YES` (see [§11](#11-export-compliance)) |
| App Privacy label | Data Not Collected (see [§9](#9-app-privacy-nutrition-label)) |

The privacy, support, and marketing pages are deployed from [`web/`](web/) on Vercel and return HTTP 200.

## 2. What is in `release/`

| Path | What it is |
|---|---|
| [`release/release.sh`](release/release.sh) | Runs unit tests, archives a Release build, then exports an `.ipa` or uploads straight to App Store Connect |
| [`release/ExportOptions.plist`](release/ExportOptions.plist) | App Store Connect export settings (automatic signing, team `AYL8H487NP`, symbols uploaded) |
| [`release/screenshots.sh`](release/screenshots.sh) | Captures App Store screenshots on a 6.9" iPhone and a 13" iPad simulator |
| [`release/tools/sample-photos.swift`](release/tools/sample-photos.swift) | Generates 12 neutral, license-free sample photos used as screenshot content |
| [`release/screenshots/`](release/screenshots/) | Raw captured PNGs: `iphone-6.9/` and `ipad-13/` |
| [`release/tools/marketing-assets.swift`](release/tools/marketing-assets.swift) | Builds the captioned screenshots, product page header and search results image from the raw captures |
| [`release/app-preview.sh`](release/app-preview.sh) | Records and encodes the iPhone and iPad app preview videos |
| [`release/assets/`](release/assets/) | Upload-ready marketing assets ([§7a](#7a-app-store-marketing-assets)) |
| [`release/metadata/en-US/`](release/metadata/en-US/) | Paste-ready listing text: name, subtitle, promotional text, description, keywords, release notes, URLs |
| [`release/metadata/review_information/notes.txt`](release/metadata/review_information/notes.txt) | Notes for App Review (how to test, Web Upload, encryption) |
| [`release/metadata/*.txt`](release/metadata/) | Copyright and categories |

The metadata folder uses the `fastlane deliver` layout, so you can automate listing uploads later with `fastlane deliver` without renaming anything.

Screenshot capture uses `KeepshireUITests/AppStoreScreenshotTests.swift`. It is skipped in normal test runs and only runs when the script sets `SCREENSHOT_DIR`.

## 3. Release configuration in the project

These are already set; verify them if you change project settings.

- **Signing:** Automatic, team `AYL8H487NP`, for both `Keepshire` and `KeepshireShare`. The app and the share extension must share the same version and build; `release.sh` sets both.
- **Entitlements:** App Groups only (`group.dev.haresh.keepshire`) on both targets.
- **Info.plist:** `NSFaceIDUsageDescription`, `NSLocalNetworkUsageDescription`, `ITSAppUsesNonExemptEncryption = YES`, explicit `UILaunchScreen`, all four iPad orientations (required for iPad multitasking).
- **Privacy manifest** (`Keepshire/PrivacyInfo.xcprivacy`): UserDefaults `CA92.1`, file timestamp `C617.1` (`attributesOfItem` for the Settings storage total), no tracking, no collected data. If you add a required-reason API (disk space, system boot time, active keyboards, file timestamps outside the container), add it here or App Store Connect emails an `ITMS-91053` warning.
- **App icon:** 1024×1024 PNG with no alpha channel, plus dark and tinted variants.
- **Debug-only code:** the Settings developer section and the `--ui-testing` launch hooks are compiled only in Debug, so Release builds cannot reset the vault from launch arguments.
- **Release build:** compiles cleanly. Remaining warnings are deprecations (`copyCGImage`, `tracks(withMediaType:)`, `duration`, `shouldUseExtendedBackgroundIdleMode`) and do not block submission.

---

## 4. Apple Developer account setup (one time)

1. Enroll in the [Apple Developer Program](https://developer.apple.com/programs/) as an **Individual** with the Apple ID you will publish under. Wait until membership shows **Active**.
2. In [App Store Connect](https://appstoreconnect.apple.com/) → **Business** (Agreements, Tax, and Banking), accept the **Free Apps** agreement. A paid agreement, tax forms, and bank details are only needed if you later charge for the app.
3. In Xcode → **Settings → Accounts**, add the same Apple ID and confirm team `AYL8H487NP` appears.

### Register identifiers (one time)

At [developer.apple.com → Identifiers](https://developer.apple.com/account/resources/identifiers/list):

1. **+** → **App Groups** → description `Keepshire`, identifier `group.dev.haresh.keepshire`.
2. **+** → **App IDs** → **App** → Explicit `dev.haresh.keepshire`, description `Keepshire`. Enable **App Groups** → Configure → select `group.dev.haresh.keepshire`.
3. **+** → **App IDs** → **App** → Explicit `dev.haresh.keepshire.share`, description `Keepshire Share`. Enable **App Groups** → select the same group.
4. Leave Push Notifications, iCloud, and Associated Domains off. (Keepshire only uses local notifications, which need no capability.)

With automatic signing, Xcode creates the distribution certificate and App Store provisioning profiles during the first archive.

## 5. Create the App Store Connect record (one time)

1. App Store Connect → **Apps** → **+** → **New App**.
2. Platform **iOS**, name `Keepshire: Private Photo Vault`, primary language **English (U.S.)**, bundle ID `dev.haresh.keepshire`, SKU `keepshire`, user access **Full Access**.
3. **App Information**: subtitle, privacy policy URL, categories (Utilities / Photo & Video), content rights → "does not contain, show, or access third-party content".
4. **Pricing and Availability**: price **Free**, all countries or regions (see [§11](#11-export-compliance) for France).

If the name is taken, App Store Connect rejects it at this step. Pick a variant (for example `Keepshire - Photo Vault`) and update `release/metadata/en-US/name.txt`.

---

## 6. Pre-flight checks (every release)

1. **Working tree clean** on `main`, all release changes committed.
2. **Unit tests** (also run by `release.sh`):
   ```bash
   xcodebuild -project Keepshire.xcodeproj -scheme Keepshire -destination 'platform=iOS Simulator,name=iPhone 18 Pro' test -only-testing:KeepshireTests -parallel-testing-enabled NO
   ```
3. **UI smoke tests** on an iPhone and an iPad simulator:
   ```bash
   xcodebuild -project Keepshire.xcodeproj -scheme Keepshire -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M5)' test -only-testing:KeepshireUITests -parallel-testing-enabled NO
   ```
4. **Manual pass** of [docs/TESTING_CHECKLIST.md](docs/TESTING_CHECKLIST.md) on a physical iPhone, at minimum: first launch, Face ID unlock, import from Photos and Files, Share extension import, video playback, Web Upload from a laptop browser, auto-lock, screenshot blanking, decoy passcode, trash, and passcode change.
5. **Open items in `TODO.txt`:** confirm "Screen protection not working" and "Upload 2 GB file breaks app" are fixed or acceptable for 1.0. Imports above 2 GB are rejected by design; verify that a 1.9 GB video imports without crashing on a real device.
6. **Live URLs:** in Settings → About, Privacy Policy and Support open the live pages.

## 7. Screenshots

App Store Connect accepts only exact pixel sizes per display slot, and rejects other sizes with "File dimensions are invalid". The required slots are **iPhone with Dynamic Island (medium display)** and **iPad 13" display**. The large iPhone slot is optional; other slots are scaled from these.

| App Store Connect slot | Required | Pixel size (portrait) | Files |
|---|---|---|---|
| iPhone with Dynamic Island (medium display) | Yes | 1206 × 2622 (or 1179 × 2556) | `release/assets/screenshots/iphone-6.3/` |
| iPhone with Dynamic Island (large display) | No | 1320 × 2868 (or 1290 × 2796, 1260 × 2736) | `release/assets/screenshots/iphone-6.9/` |
| iPad 13" display | Yes, the app runs on iPad | 2064 × 2752 (or 2048 × 2732) | `release/assets/screenshots/ipad-13/` |

The raw captures come from an iPhone 18 Pro Max (1320 × 2868) and an iPad Pro 13-inch (M5) simulator. `release/tools/marketing-assets.swift` renders the captioned iPhone set natively at both iPhone sizes.

Capture them:

```bash
release/screenshots.sh
```

The script erases both simulators, stages the generated sample photos in the app's App Group share inbox (the app imports them on unlock, the same path the Share extension uses), sets a 9:41 status bar with full battery, and runs `AppStoreScreenshotTests`. Screenshot Protection blanks every capture, so the test turns it off in Settings before capturing and turns it back on at the end. If you capture by hand (simulator ⌘S or a device), do the same: Settings → Advanced Security → Screenshot Protection off, capture, then on again. It saves seven PNGs per device:

1. `01-lock` – passcode lock screen
2. `02-gallery` – gallery with imported photos
3. `03-viewer` – full-screen photo viewer
4. `04-folders` – folders (Travel, Family, Documents, Receipts)
5. `05-categories` – category browser
6. `06-web-upload` – Web Upload tab
7. `07-settings` – security settings

Override the simulators with `IPHONE_SIM="..." IPAD_SIM="..." release/screenshots.sh` if your Xcode has different device names.

These raw captures feed the captioned screenshots in [§7a](#7a-app-store-marketing-assets); upload those, not the raw files.

## 7a. App Store marketing assets

Built to Apple's [App Store asset best practices](https://developer.apple.com/app-store/asset-best-practices/) and the [creative asset](https://developer.apple.com/help/app-store-connect/reference/app-information/creative-assets-specifications), [screenshot](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications) and [app preview](https://developer.apple.com/help/app-store-connect/reference/app-information/app-preview-specifications) specifications. Everything is in [`release/assets/`](release/assets/).

| Asset | File(s) | Spec |
|---|---|---|
| Captioned screenshots, iPhone medium (required) | `screenshots/iphone-6.3/01…06.png` | 1206 × 2622 PNG, no alpha |
| Captioned screenshots, iPhone large | `screenshots/iphone-6.9/01…06.png` | 1320 × 2868 PNG, no alpha |
| Captioned screenshots, iPad 13" | `screenshots/ipad-13/01…05.png` | 2064 × 2752 PNG, no alpha |
| Product page header | `product-page-header.png` | 21:9, 3840 × 1646 PNG |
| Search results | `search-results.png` | 3:2, 3840 × 2560 PNG |
| App preview, iPhone (any iPhone slot) | `app-preview/iphone-6.9.mov` | 886 × 1920, 30 fps H.264 High@4.0, 11 Mbps, silent 256 kbps AAC, 15–30 s |
| App preview, iPad 13" | `app-preview/ipad-13.mov` | 1200 × 1600, same encoding |

How they follow the guidelines:

- **Screenshots** lead with the strongest idea (the private gallery) and tell a story: lock → organize → view → find → import. Each has one short headline and one supporting line over the brand gradient from the app icon, with the real UI underneath. No prices, URLs, © symbols, awards, or other platforms.
- **Header and search art** keep the key art (three real screens) centered so nothing important falls outside the template safe area. The search image states the name and purpose up front.
- **App previews** are a real recording of the app: unlock → folders → gallery → photo viewer → Web Upload → folders. They work muted, avoid fast cuts, and fade through black at both ends so the autoplay loop has no jump. The default poster frame (5 s) lands on the folders screen.
- **Content** uses only generated sample photos, so everything is suitable for a 4+ rating and has no licensing questions.
- **Localization:** the app ships in English only, so there is one set.

Regenerate:

```bash
release/screenshots.sh
```
```bash
swift release/tools/marketing-assets.swift .
```
```bash
release/app-preview.sh
```

The first refreshes the raw captures. The second rebuilds the captioned screenshots, header and search art from them; edit the captions at the top of [`release/tools/marketing-assets.swift`](release/tools/marketing-assets.swift). The third records both previews; it needs `ffmpeg` (`brew install ffmpeg`). Use `IPHONE_SIM=skip` or `IPAD_SIM=skip` to record one device. Like the screenshot test, the preview test turns Screenshot Protection and Screen Recording Protection off before recording and back on at the end. The automated test runner sometimes stalls before launching the app; if a run sits on the Home Screen for more than a few minutes, stop it and run it again. If xcodebuild hangs after the tour has finished, the script stops it after a minute and encodes the clip anyway.

### Recording a preview by hand

1. In Keepshire on an iPad 13" simulator (or device), go to Settings → Security → Advanced Security and turn off **Screenshot Protection** and **Screen Recording Protection**. Import a few neutral photos first.
2. Record 18–28 seconds of the same tour: unlock → Folders → Gallery → open a photo and swipe once → close → Web Upload → Folders. Move slowly; no fast cuts. On a simulator:
   ```bash
   xcrun simctl io booted recordVideo --codec=h264 ipad-raw.mov
   ```
   Press Ctrl-C to stop. On a device, use Control Center screen recording.
3. Encode it to the App Store spec. Set `-ss` and `-t` to the start time and length you want to keep:
   ```bash
   ffmpeg -ss 0 -t 25 -i ipad-raw.mov -f lavfi -t 25 -i anullsrc=channel_layout=stereo:sample_rate=48000 -vf "scale=1200:1600:flags=lanczos,fps=30,format=yuv420p,fade=t=in:st=0:d=0.4,fade=t=out:st=24.6:d=0.4" -c:v libx264 -profile:v high -level:v 4.0 -b:v 11M -minrate 11M -maxrate 11M -bufsize 11M -x264-params nal-hrd=cbr:filler=1 -c:a aac -b:a 256k -ar 48000 -ac 2 -movflags +faststart -shortest release/assets/app-preview/ipad-13.mov
   ```
   Change `fade=t=out:st=` to the length minus 0.4 s.
4. Turn both protections back on.

Upload:

- **Screenshots and previews:** App Store Connect → the version → **Previews and Screenshots**. Under **iPhone with Dynamic Island (medium display)**, put `app-preview/iphone-6.9.mov` first, then the `iphone-6.3` screenshots in order. Optionally do the same with the `iphone-6.9` screenshots under the **large display** slot. Put `app-preview/ipad-13.mov` and the `ipad-13` screenshots under **iPad 13" display**. Previews can take up to 24 hours to process.
- **Product page header and search results:** App Store Connect → the app → **Asset Library** (or with a new version). Check them in the product page preview tool before publishing.

Not included:

- **In-App Event cards** (16:9 card, 9:16 detail): Keepshire has no In-App Events.
- **Layered app icon:** Apple recommends a layered icon made in Icon Composer (Liquid Glass). The app ships a 1024 × 1024 icon with dark and tinted variants, which App Store Connect accepts. To make a layered version, open the icon artwork in Icon Composer (Xcode → Open Developer Tool) and add the `.icon` file to the app target.

## 8. Archive and upload

### Option A – script (recommended)

```bash
release/release.sh 1.0 1 --upload
```

This runs unit tests, archives Release with version `1.0` build `1` for both targets, and uploads using the Apple ID signed in to Xcode. Without `--upload` it writes `build/release/1.0-1/export/Keepshire.ipa`, which you can upload with Apple's **Transporter** app.

To upload without an Xcode login (CI or another Mac), create an App Store Connect API key (Users and Access → Integrations → App Store Connect API, role **App Manager**) and run:

```bash
ASC_KEY_ID=XXXXXXXXXX ASC_ISSUER_ID=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx ASC_KEY_PATH=~/keys/AuthKey_XXXXXXXXXX.p8 release/release.sh 1.0 1 --upload
```

Keep the `.p8` file out of the repo.

Set `SKIP_TESTS=1` to skip the unit tests when you have just run them.

### Option B – Xcode

1. Select the **Keepshire** scheme and **Any iOS Device (arm64)**.
2. Set Version `1.0` and Build `1` on **both** the Keepshire and KeepshireShare targets (General tab).
3. **Product → Archive**.
4. In the Organizer: **Validate App** first, then **Distribute App → App Store Connect → Upload**.

### After upload

Processing takes 5–30 minutes. App Store Connect emails you if the build has issues (for example `ITMS-91053` for a missing privacy-manifest reason, or `ITMS-90683` for a missing usage description). Fix, bump the build number, and upload again — a build number can never be reused for the same version.

## 9. App Privacy (nutrition label)

App Store Connect → **App Privacy** → **Get Started**:

- "Do you or your third-party partners collect data from this app?" → **No, we do not collect data from this app.**
- Result shown on the store: **Data Not Collected**.

Why this is accurate: there is no account, analytics, ads, or server. Imported files, credentials, and settings never leave the device. Web Upload moves files from the user's own browser to their own phone on the local network; nothing reaches you. MetricKit diagnostics are only recorded locally. Crash reports that users choose to share with developers through Apple are not collected by the app.

## 10. Age rating

App Store Connect → **App Information** → **Age Rating** → Edit. Answer:

| Question group | Answer |
|---|---|
| All content descriptors (violence, sexual content, profanity, horror, drugs, gambling, contests, medical, etc.) | **None** |
| Unrestricted web access | **No** (Web Upload is a local server, not a browser) |
| User-generated content | **No** (imported files are private to the device owner; nothing is shared between users) |
| Messaging and chat | **No** |
| Advertising | **No** |
| Parental controls / age assurance | **No** |

Expected rating: **4+**.

## 11. Export compliance

`ITSAppUsesNonExemptEncryption` is **YES** in `Keepshire/Info.plist`. That is a deliberate project decision ([docs/DEVELOPER_GUIDE.md → Export compliance](docs/DEVELOPER_GUIDE.md#export-compliance)): Keepshire encrypts files at rest with AES-GCM, not only HTTPS. Do not change it to skip the questions.

Because the key is YES, App Store Connect asks the encryption questions when you first attach a build (TestFlight or the App Store version). The wording changes over time; answer to match the facts:

| Fact | Answer |
|---|---|
| Uses encryption | Yes |
| Proprietary or non-standard algorithms | No — AES-GCM (CryptoKit), PBKDF2-HMAC-SHA256 (CommonCrypto), ECDSA and TLS 1.2+ (Security / Network) |
| Implements standard algorithms instead of, or in addition to, Apple's OS encryption | No — all crypto calls go to Apple frameworks |
| Purpose | Protecting the user's own files on their device; HTTPS for the optional local transfer server |

If Connect then asks for documentation, upload what it requests (for U.S. mass-market products this is typically a self-classification report, filed with BIS by 1 February each year). If you distribute in **France**, Connect may ask for a French encryption declaration; either provide it or exclude France in Pricing and Availability.

After Apple approves the documentation, it gives you a key. Add `ITSEncryptionExportComplianceCode` with that value to `Keepshire/Info.plist` so later builds skip the questions.

This guide is not legal advice; confirm with an export-compliance lawyer if unsure.

## 12. Fill in the version page

App Store Connect → the app → **iOS App 1.0**. Paste from the metadata files:

| Field | Source file | Limit |
|---|---|---|
| Promotional text | `release/metadata/en-US/promotional_text.txt` | 170 |
| Description | `release/metadata/en-US/description.txt` | 4000 |
| Keywords | `release/metadata/en-US/keywords.txt` | 100 bytes |
| Support URL | `release/metadata/en-US/support_url.txt` | – |
| Marketing URL | `release/metadata/en-US/marketing_url.txt` | – |
| Copyright | `release/metadata/copyright.txt` | – |
| What's New | `release/metadata/en-US/release_notes.txt` (not shown for 1.0; required from 1.0.1) | 4000 |

Then:

- **Build:** select the processed build.
- **App Review Information:** sign-in required → **No**. Contact: your name, phone, and `hello@haresh.dev`. Notes: paste `release/metadata/review_information/notes.txt`.
- **Version release:** choose **Manually release this version** for the first launch so you control the day it goes live.
- **Phased release:** optional for updates; not useful for 1.0.

## 13. TestFlight (recommended before submitting)

1. TestFlight tab → **Internal Testing** → create a group, add yourself, add the build.
2. Install from the TestFlight app on a physical iPhone and iPad.
3. Repeat the core flows from [§6](#6-pre-flight-checks-every-release) on the TestFlight build — this is the exact binary Apple reviews.
4. External testers need a short Beta App Review; fill **Test Information** with the same review notes.

## 14. Submit for review

1. On the version page, **Add for Review** → **Submit to App Review**.
2. Review typically takes 24–48 hours. Status changes arrive by email and in the App Store Connect app.
3. If approved with manual release, press **Release This Version** when ready. The listing goes live within about 24 hours.

### Likely review questions and how to respond

| Topic | Risk | Response |
|---|---|---|
| Web Upload server | Reviewer cannot reach it or asks why a server runs on the phone | Notes already explain it is local-network only, opt-in, HTTPS, and paired by code. Offer a screen recording if asked. |
| Self-signed certificate warning | Reviewer thinks it is a security flaw | Explain the certificate is created on the device per session; the fingerprint is shown in the app for verification. |
| Decoy passcode | Concern about deception (Guideline 2.3 / 5.1) | It only opens an empty UI of the same app; it does not impersonate another app or hide the app icon. |
| Screenshot blanking | Use of a private API | It uses a public `UITextField.isSecureTextEntry` layer; no private selectors. |
| "Vault" naming | Confusion with Apple FileVault | The listing never says FileVault. |
| Forgotten passcode | Data loss complaints | The description and support page state there is no recovery. |
| Metadata (Guideline 2.3.7) | Keyword stuffing or competitor names | Keywords contain no brand names. |

To reply to a rejection, use **Resolution Center** in App Store Connect. Fix code issues with a new build (bump the build number); fix metadata issues directly and resubmit.

## 15. After release

1. Tag the commit that produced the build:
   ```bash
   git tag -a v1.0-1 -m "Keepshire 1.0 (1) – App Store release"
   ```
   ```bash
   git push origin v1.0-1
   ```
2. Keep the `.xcarchive` from `build/release/1.0-1/` (it holds the dSYMs for symbolicating crash reports). Copy it to Xcode's archives or back it up; `build/` is git-ignored.
3. Watch **Xcode → Organizer → Crashes** and App Store Connect **Ratings and Reviews** during the first week.

## 16. Shipping an update

1. Fix and test; update the docs the change affects.
2. Choose the next version (`1.0.1` for fixes, `1.1` for features) and reset the build to `1`, or keep increasing the build — it only has to go up within a version.
3. Update `release/metadata/en-US/release_notes.txt` (What's New is required for updates).
4. If the UI changed, rerun `release/screenshots.sh` and replace the screenshots.
5. App Store Connect → **+ Version or Platform** → iOS → enter the version.
6. `release/release.sh <version> <build> --upload`, then follow [§12](#12-fill-in-the-version-page)–[§15](#15-after-release). Privacy, age rating, and export answers carry over unless the app changed in those areas.

## 17. Troubleshooting

| Problem | Fix |
|---|---|
| `No profiles for 'dev.haresh.keepshire.share' were found` | Register the share extension App ID and enable App Groups on it ([§4](#register-identifiers-one-time)), then archive again with `-allowProvisioningUpdates` (the script passes it). |
| `Provisioning profile doesn't include the com.apple.security.application-groups entitlement` | The App Group is not assigned to that App ID. Configure it on both IDs. |
| `The bundle version must be higher than the previously uploaded version` | Increase the build number. |
| `CFBundleVersion of the app extension does not match the parent app` | Archive with `release.sh`, or set the same version/build on both targets in Xcode. |
| `ITMS-91053: Missing API declaration` | Add the named required-reason API to `PrivacyInfo.xcprivacy`. |
| `ITMS-90474` / iPad multitasking orientation error | Keep all four orientations in `UISupportedInterfaceOrientations~ipad`. |
| Build shows "Missing Compliance" in TestFlight | Answer the export questions on the build ([§11](#11-export-compliance)). |
| `screenshots.sh` says no simulator found | Create the device in Xcode → Window → Devices and Simulators, or pass `IPHONE_SIM` / `IPAD_SIM`. |
| Screenshot test fails with "No staged photos were imported" | Run the whole script (it erases the simulator and stages the sample photos first) instead of running the test alone. |
| Screenshots come out black | Screenshot Protection was on. The test turns it off first; for manual captures, turn it off in Settings → Advanced Security and back on afterwards. |
| Upload fails with an authentication error | Sign in again under Xcode → Settings → Accounts, or use an App Store Connect API key. |

# Keepshire

A private, encrypted vault for photos, videos, audio, and documents on iPhone and iPad. No account, no cloud: everything stays on the device.

App Store name: **Keepshire: Private Photo Vault** · Website: [keepshire.haresh.dev](https://keepshire.haresh.dev)

## What it does

- **Lock** with a 4-digit passcode, 6-digit passcode, or password, plus optional Face ID or Touch ID.
- **Recover** a forgotten passcode with an optional recovery key.
- **Encrypt** every file, thumbnail, and file name with AES-GCM.
- **Organize** in nested folders, a gallery, and categories, with search, sort, favorites, and trash.
- **Import** from Photos, Files, the Share sheet, or a computer's browser over Wi-Fi.
- **View** photos, videos, audio, PDFs, and documents without leaving the vault.
- **Protect** with blank screenshots, a screen-recording cover, shake or flip to lock, and a decoy passcode.

## Quick start

1. Open `Keepshire.xcodeproj` in Xcode.
2. Pick an iPhone simulator.
3. Press **⌘R**.

Requires iOS 18.5 or later. No dependencies to install. For devices, signing, and the command-line installer, see [Development](docs/DEVELOPMENT.md).

Run the unit tests (serially):

```bash
xcodebuild -project Keepshire.xcodeproj -scheme Keepshire -destination 'platform=iOS Simulator,name=iPhone 18 Pro' test -only-testing:KeepshireTests -parallel-testing-enabled NO
```

## Documentation

| Document | Read it to |
|---|---|
| [Features](docs/FEATURES.md) | Learn what the app does, screen by screen |
| [Architecture](docs/ARCHITECTURE.md) | Understand how the code is organized and how data flows |
| [Security model](docs/SECURITY.md) | See how files and keys are protected, and the limits |
| [Development](docs/DEVELOPMENT.md) | Set up, build, run on a device, and change the code |
| [Testing](docs/TESTING.md) | Run the tests and the manual release checklist |
| [Release](docs/RELEASE.md) | Ship to TestFlight and the App Store |
| [Decisions](docs/decisions/) | Read why key design choices were made |

Planned work lives in [TODO.txt](TODO.txt).

## Repository

```
Keepshire/          App source
KeepshireShare/     Share Extension
KeepshireTests/     Unit tests
KeepshireUITests/   UI tests and App Store screenshot capture
docs/               Documentation
release/            Release scripts, store metadata, marketing assets
web/                Website (home, privacy, support)
```

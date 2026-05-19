# Present

An iOS SwiftUI demo that reads/writes NDEF NFC tags and uses Apple's Screen Time APIs to shield selected apps.

## What this proves

- The iPhone can write simple NDEF command payloads to compatible writable NFC tags.
- The app can read those commands later through an in-app Core NFC scan session.
- A scanned command can toggle app shielding through `FamilyControls` and `ManagedSettings`.

## Quick Start

1. Open `FocusNFCDemo.xcodeproj` in Xcode.
2. Select the `FocusNFCDemo` target and set your development team in **Signing & Capabilities**.
3. Confirm the shared `FocusNFCDemo` scheme is selected.
4. Choose a physical NFC-capable iPhone as the run destination.
5. Press **Play**.
6. In the app, tap **Authorize Screen Time**, choose apps to shield, then use the simulation buttons or NFC write/scan controls.

For the full setup flow, see [docs/setup/xcode-signing.md](docs/setup/xcode-signing.md). For command-line builds, see [docs/setup/cli-builds.md](docs/setup/cli-builds.md).

## Hardware

Use a physical NFC-capable iPhone and rewritable NDEF-compatible tags, such as NTAG215 or NTAG216 cards. NFC and Screen Time shielding cannot be fully tested in the iOS simulator.

## Important iOS constraints

- NFC cannot silently perform arbitrary actions. This demo uses an in-app NFC scan sheet.
- Blocking other apps requires Apple's Screen Time APIs and user authorization.
- Family Controls distribution requires Apple approval before App Store release.

## More Docs

- [Docs index](docs/README.md)
- [Xcode signing and setup](docs/setup/xcode-signing.md)
- [Run on a physical iPhone](docs/setup/run-on-device.md)
- [Command-line builds](docs/setup/cli-builds.md)
- [TestFlight upload](docs/setup/testflight-upload.md)
- [Build configurations](docs/reference/build-configurations.md)
- [Developer tooling notes](docs/reference/tooling.md)

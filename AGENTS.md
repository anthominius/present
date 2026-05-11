# Agent context: Focus NFC Demo

Single-target iOS app (SwiftUI) that writes and reads NDEF NFC tags carrying `focus://shield/on` and `focus://shield/off`, then toggles app shielding via Apple Screen Time APIs when **restricted** capabilities are enabled. User-facing setup, signing, and runbook live in [README.md](README.md).

## Tech stack

- Swift 5, SwiftUI, iOS deployment target **16.0**
- Core NFC (`NFCSessionManager`) for NDEF read/write
- Optional: `FamilyControls` + `ManagedSettings` behind compile flag `FOCUS_RESTRICTED_CAPABILITIES`

## Repository layout

```
.
├── AGENTS.md
├── README.md
├── FocusNFCDemo/                    # Application sources and resources
│   ├── FocusNFCDemoApp.swift        # @main entry, injects FocusAppModel
│   ├── ContentView.swift            # UI: status, app picker hooks, NFC controls
│   ├── FocusAppModel.swift          # Shielding state, Screen Time auth, command handling, FocusCommand
│   ├── NFCSessionManager.swift      # NFCNDEFReaderSession delegate, NDEF URI payloads
│   ├── Info.plist                   # Bundle metadata; NFCReaderUsageDescription
│   ├── FocusNFCDemo.entitlements    # family-controls + NDEF reader session (used on *Restricted* configs)
│   ├── Assets.xcassets/
│   └── Preview Content/
│       └── Preview Assets.xcassets/
└── FocusNFCDemo.xcodeproj/
    ├── project.pbxproj              # Target, build configurations, signing, capabilities flags
    ├── project.xcworkspace/
    │   └── contents.xcworkspacedata
    └── xcshareddata/xcschemes/
        └── FocusNFCDemo.xcscheme    # Run/Test/Archive use *Restricted* configurations
```

**Ephemeral / machine-local (often gitignored elsewhere):** `xcuserdata/` under the `.xcodeproj` may contain per-developer scheme data; prefer **`xcshareddata/xcschemes`** for shared scheme behavior.

## Xcode project map

| Item | Location |
|------|----------|
| Single app target | `FocusNFCDemo` in `project.pbxproj` |
| Bundle ID | `PRODUCT_BUNDLE_IDENTIFIER` → `com.anthonymadrazo.FocusNFCDemo` |
| Entitlements path | `CODE_SIGN_ENTITLEMENTS` only on **Debug Restricted** / **Release Restricted** |
| Info.plist | `INFOPLIST_FILE` → `FocusNFCDemo/Info.plist` |
| SwiftUI preview assets | `DEVELOPMENT_ASSET_PATHS` → `FocusNFCDemo/Preview Content` |
| Capabilities (Xcode metadata) | `SystemCapabilities` in `PBXProject` for Family Controls + NFC Tag Reading |

Shared scheme **`FocusNFCDemo.xcscheme`** uses **Debug Restricted** for Run/Test/Analyze and **Release Restricted** for Profile/Archive.

## Build configurations (critical for agents)

| Configuration | `FOCUS_RESTRICTED_CAPABILITIES` | Entitlements | Behavior |
|---------------|----------------------------------|--------------|----------|
| Debug / Release | off | not applied | Simulator-friendly: `FamilyControls` / `ManagedSettings` compiled out; UI shows “restricted APIs compiled out” |
| Debug Restricted / Release Restricted | on (`SWIFT_ACTIVE_COMPILATION_CONDITIONS`) | `FocusNFCDemo.entitlements` | Full flow: picker, authorization, `ManagedSettingsStore`, real shielding |

Any change that touches `#if FOCUS_RESTRICTED_CAPABILITIES` blocks must stay consistent in **both** code paths (restricted vs stub) so **Debug** still builds for Simulator/UI work.

## Runtime architecture (where logic lives)

- **`FocusAppModel`:** `@MainActor` `ObservableObject`; owns shield on/off, Screen Time authorization summary, persists `FamilyActivitySelection` to `UserDefaults` (key `FocusNFCDemo.familyActivitySelection`). **`FocusCommand`** and `parse(_:)` live at bottom of this file.
- **`NFCSessionManager`:** `@MainActor` `ObservableObject`; owns `NFCNDEFReaderSession`, writes URI NDEF payloads via `NFCNDEFPayload.wellKnownTypeURIPayload(string:)`, parses scan results into `FocusCommand`.
- **`ContentView`:** Composes UI; holds `@StateObject` `NFCSessionManager`; calls `model.handle(command)` from scans or manual simulation.

## Capabilities and privacy

- **Entitlements:** `com.apple.developer.family-controls`, `com.apple.developer.nfc.readersession.formats` → NDEF.
- **Usage description:** `NFCReaderUsageDescription` in `Info.plist`.
- App selection uses opaque tokens; UI must not assume access to app names outside system UI.

## Constraints agents should remember

1. **NFC:** Requires a physical NFC-capable device; `NFCNDEFReaderSession.readingAvailable` is often false in Simulator.
2. **Shielding:** Real enforcement needs **Restricted** build + approved Screen Time authorization + at least one selected application token.
3. **Family Controls:** Distribution beyond local dev may require Apple approval; see README.
4. **Conditional compilation:** Prefer extending existing `#if FOCUS_RESTRICTED_CAPABILITIES` sections rather than duplicating large SwiftUI trees; follow the existing split (`contentForm` vs restricted-only modifiers).

## Suggested verification

- After Swift or project changes: build **Debug** (Simulator) and **Debug Restricted** (device or same SDK) in Xcode, or `xcodebuild -scheme FocusNFCDemo -configuration "Debug Restricted" -destination 'generic/platform=iOS'` when the environment is configured.
- Cross-check entitlement and compilation-flag alignment if adding new restricted APIs.

## Documentation split

- **README.md:** Human onboarding, signing, scheme switching, device steps.
- **AGENTS.md:** Structural map, build flags, file responsibilities, and constraints for automated or IDE agents.

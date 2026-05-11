# Command-Line Builds

Use this guide when building the app from Terminal with `xcodebuild`.

## Build the Restricted Configuration

When the environment is configured for Xcode command-line builds, run:

```sh
xcodebuild -scheme FocusNFCDemo -configuration "Debug Restricted" -destination 'generic/platform=iOS'
```

This checks the restricted compile path, including `FamilyControls`, `ManagedSettings`, and the entitlements used for real NFC and shielding behavior.

## If Builds Still Point at Command Line Tools

You can run the app from Xcode's Play button even if command-line tools are not fully configured. If Terminal commands such as `xcodebuild -version` say the active developer directory is `/Library/Developer/CommandLineTools`, switch it after Xcode finishes installing:

```sh
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
xcodebuild -version
```

This only affects command-line builds. The Xcode app itself can still open the project and run it on your iPhone.

# Build Configurations

This project has two build modes.

## Standard Configurations

`Debug` and `Release` are simulator-friendly UI modes. Restricted Screen Time APIs are compiled out with `#if FOCUS_RESTRICTED_CAPABILITIES`.

## Restricted Configurations

`Debug Restricted` and `Release Restricted` are real-device modes. These compile in `FamilyControls`, `ManagedSettings`, and the entitlements needed for app shielding and NFC tag reading.

The shared `FocusNFCDemo` scheme is configured to run with `Debug Restricted`, so after your Apple Developer Program membership is active you can select the `FocusNFCDemo` scheme, choose your physical iPhone, and press Play.

## Switch Build Configuration Manually

1. In Xcode, choose **Product > Scheme > Edit Scheme...**.
2. Select **Run** in the left sidebar.
3. Set **Build Configuration** to **Debug Restricted** for the full NFC/app-shielding demo.
4. Set it back to **Debug** only if you need the simulator-friendly UI-only mode.

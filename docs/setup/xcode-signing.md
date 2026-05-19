# Xcode Signing and Setup

Use this guide to open the project, set the development team, and run the restricted build on a physical iPhone.

## Open the Project

1. Open `FocusNFCDemo.xcodeproj` in Xcode.
2. In the left sidebar, click the blue `FocusNFCDemo` project icon.
3. In the project editor, select the `FocusNFCDemo` target under **Targets**.
4. Open the **Signing & Capabilities** tab.
5. Set your development team.
6. Confirm these capabilities are present:
   - Near Field Communication Tag Reading
   - Family Controls
   - Family Controls App and Website Usage

For the Screen Time dashboard report, both the `FocusNFCDemo` app target and the `PresentScreenTimeReport` extension target must be signed with Family Controls and Family Controls App and Website Usage. If the device only reports `Approved` instead of `Approved with data access`, revoke Screen Time authorization for the app, rebuild with those capabilities, and tap **Authorize Screen Time** again.

## Set Your Development Team

Use the app-specific target page in Xcode:

1. Open `FocusNFCDemo.xcodeproj`.
2. Click the blue `FocusNFCDemo` project icon in the file navigator.
3. Select the `FocusNFCDemo` target, not just the project.
4. Open **Signing & Capabilities**.
5. Under **Signing**, check **Automatically manage signing**.
6. Choose **Personal Team** from the **Team** dropdown.
7. The project currently uses `com.anthonymadrazo.FocusNFCDemo`. Change the **Bundle Identifier** if Xcode says it is already taken.

For local device testing, a Personal Team is usually enough. App Store distribution and some restricted entitlement workflows may require a paid Apple Developer Program account.

## Physical Device Notes

The simulator is useful for learning the UI, but Core NFC does not work in the simulator. To test NFC and real app shielding, use a physical iPhone with the `Debug Restricted` configuration.

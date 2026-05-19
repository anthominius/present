# TestFlight Upload

Use this when you are ready to upload a beta build to App Store Connect for TestFlight.

## Prerequisites

- Paid Apple Developer Program membership.
- App record created in App Store Connect for the bundle ID used by this project.
- `FocusNFCDemo` target signed with the same Developer Program team.
- Family Controls entitlement approved and enabled for the app identifier if you are distributing the restricted build.
- NFC Tag Reading capability enabled for the app identifier.

## Before Archiving

1. Open `FocusNFCDemo.xcodeproj` in Xcode.
2. Select the shared `FocusNFCDemo` scheme.
3. Select **Any iOS Device (arm64)** as the run destination.
4. Confirm the Archive action uses `Release Restricted`.
   - Open **Product > Scheme > Edit Scheme...**
   - Select **Archive**.
   - Confirm **Build Configuration** is `Release Restricted`.
5. Increment the build number.
   - Select the `FocusNFCDemo` target.
   - Open **General**.
   - Update **Build** to a value higher than the last uploaded build.
6. Build once locally with the restricted path:

```sh
xcodebuild -scheme FocusNFCDemo -configuration "Release Restricted" -destination 'generic/platform=iOS' build
```

## Upload from Xcode

1. In Xcode, choose **Product > Archive**.
2. When Organizer opens, select the new archive.
3. Click **Distribute App**.
4. Choose **App Store Connect**.
5. Choose **Upload**.
6. Leave symbol upload enabled.
7. Let Xcode manage signing unless you have a reason to use manual profiles.
8. Click through validation and upload.

After upload, wait for App Store Connect processing. The build will not appear in TestFlight until Apple finishes processing it.

## Enable TestFlight

1. Open App Store Connect.
2. Select the app.
3. Open the **TestFlight** tab.
4. Select the processed build.
5. Add beta test details if prompted.
6. Add the build to an internal testing group.
7. Invite testers.

External testing requires Apple beta review. Internal testing is the fastest path for development checks.

## Focus-Specific Checks

- Use `Release Restricted` for TestFlight if testers need real app shielding.
- Test on a physical NFC-capable iPhone. Simulator behavior does not prove NFC or Screen Time enforcement.
- The app still requires Screen Time authorization on each tester's device.
- Testers must select apps to shield inside the system picker before NFC commands can toggle anything useful.

## Common Failures

- **Archive is unavailable:** switch destination to **Any iOS Device (arm64)**.
- **Missing entitlement error:** confirm Family Controls and NFC are enabled on the App ID in Apple Developer, then refresh signing in Xcode.
- **Build does not show in TestFlight:** wait for processing, then check App Store Connect email/status. If it fails processing, Apple usually reports the reason there.
- **New upload rejected as duplicate:** increment the build number and archive again.

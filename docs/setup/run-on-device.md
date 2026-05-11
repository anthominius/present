# Run on a Physical iPhone

The simulator is useful for learning the UI, but Core NFC does not work in the simulator. To test NFC and real app shielding, use a physical iPhone.

## Device Runbook

1. Connect your iPhone to your Mac with USB, or enable wireless debugging later after USB pairing works once.
2. Unlock the iPhone and tap **Trust This Computer** if prompted.
3. In Xcode, open the destination selector near the Play button.
4. Choose your iPhone under **iOS Device**, not an iOS Simulator.
5. If Xcode says the phone is not prepared for development, wait for it to finish device setup.
6. Press **Play**.
7. On the iPhone, if the app does not open because the developer is untrusted, go to **Settings > General > VPN & Device Management** and trust your developer profile.
8. Re-run from Xcode.

## In-App Flow

After the app launches:

1. Tap **Authorize Screen Time**.
2. Tap **Choose Apps** and select one or more apps to shield.
3. If your NFC tag has not arrived, use **Simulate Shield On** and **Simulate Shield Off**.
4. When the tag arrives, use **Write Tag** to create one `focus://shield/on` tag and one `focus://shield/off` tag.
5. Use **Scan Tag** to toggle shielding from NFC.

## Temporary Workaround Without an NFC Tag

Until the NTAG215 arrives, use the manual simulation buttons in the app:

- **Simulate Shield On** runs the same command path as scanning a `focus://shield/on` NFC tag.
- **Simulate Shield Off** runs the same command path as scanning a `focus://shield/off` NFC tag.
- These buttons test Screen Time authorization, app selection, persistence, and shielding behavior.
- They do not test Core NFC reading or writing. That final piece needs the physical NFC tag and physical iPhone.

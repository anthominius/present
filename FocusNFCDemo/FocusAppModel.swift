import Foundation
#if FOCUS_RESTRICTED_CAPABILITIES
import FamilyControls
import ManagedSettings
#endif

// @MainActor means this object updates UI-facing state only on the main thread.
// That keeps SwiftUI screen updates predictable and avoids concurrency warnings.
@MainActor
final class FocusAppModel: ObservableObject {
#if FOCUS_RESTRICTED_CAPABILITIES
    // FamilyActivitySelection stores the apps the user picked in Apple's private picker.
    // The app receives opaque tokens, not app names, which protects user privacy.
    @Published var selection = FamilyActivitySelection()
#endif

    // This mirrors whether this app most recently turned shielding on.
    // ManagedSettings is the real source of enforcement; this value is for the UI.
    @Published var isShieldingEnabled = false

    // Human-readable status text shown in the main screen's Status section.
    @Published var statusMessage = "Choose apps, write a tag, then scan it to toggle shielding."

#if FOCUS_RESTRICTED_CAPABILITIES
    // Controls whether SwiftUI presents Apple's FamilyActivityPicker sheet.
    @Published var showingActivityPicker = false

    // Mirrors Apple's current Screen Time authorization state.
    @Published var authorizationStatus = AuthorizationCenter.shared.authorizationStatus

    // ManagedSettingsStore is the API surface that applies or clears app shielding.
    private let store = ManagedSettingsStore()

    // UserDefaults key used to save the opaque app-selection tokens between launches.
    private let selectionKey = "FocusNFCDemo.familyActivitySelection"
#endif

    // Initializer runs when the app model is first created.
    // It restores any previous app selection and refreshes authorization status.
    init() {
#if FOCUS_RESTRICTED_CAPABILITIES
        loadSelection()
#endif
        refreshAuthorizationStatus()
    }

    // Convenience boolean used before trying to shield apps.
    var hasSelectedApplications: Bool {
#if FOCUS_RESTRICTED_CAPABILITIES
        !selection.applicationTokens.isEmpty
#else
        true
#endif
    }

    // Produces a short label for the UI without exposing private app details.
    var selectedApplicationsSummary: String {
#if FOCUS_RESTRICTED_CAPABILITIES
        let count = selection.applicationTokens.count

        switch count {
        case 0:
            return "No apps selected"
        case 1:
            return "1 app selected"
        default:
            return "\(count) apps selected"
        }
#else
        return "Simulator mode: app picker disabled"
#endif
    }

    // Converts Apple's authorization enum into user-facing text.
    var authorizationSummary: String {
#if FOCUS_RESTRICTED_CAPABILITIES
        switch authorizationStatus {
        case .approved:
            return "Approved"
        case .approvedWithDataAccess:
            return "Approved with data access"
        case .denied:
            return "Denied"
        case .notDetermined:
            return "Not requested"
        @unknown default:
            return "Unknown"
        }
#else
        return "Simulator mode"
#endif
    }

#if FOCUS_RESTRICTED_CAPABILITIES
    private var isScreenTimeAuthorized: Bool {
        switch authorizationStatus {
        case .approved, .approvedWithDataAccess:
            return true
        case .denied, .notDetermined:
            return false
        @unknown default:
            return false
        }
    }
#endif

    // Asks iOS for Screen Time authorization.
    // Without approval, the app cannot shield other apps.
    func requestAuthorization() async {
#if FOCUS_RESTRICTED_CAPABILITIES
        do {
            try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
            refreshAuthorizationStatus()
            statusMessage = "Screen Time authorization approved."
        } catch {
            refreshAuthorizationStatus()
            statusMessage = "Screen Time authorization failed: \(error.localizedDescription)"
        }
#else
        isShieldingEnabled = false
        statusMessage = "Simulator mode: Screen Time authorization is disabled until restricted capabilities are enabled."
#endif
    }

    // Saves the FamilyActivitySelection after the picker closes.
    // PropertyListEncoder works because Apple's selection type conforms to Codable.
    func persistSelection() {
#if FOCUS_RESTRICTED_CAPABILITIES
        do {
            let data = try PropertyListEncoder().encode(selection)
            UserDefaults.standard.set(data, forKey: selectionKey)
            statusMessage = selectedApplicationsSummary
        } catch {
            statusMessage = "Could not save selected apps: \(error.localizedDescription)"
        }
#else
        statusMessage = "Simulator mode: no app selection to save."
#endif
    }

    // Central command router.
    // NFC scans and manual simulation buttons both call this function.
    func handle(_ command: FocusCommand) {
        switch command {
        case .shieldOn:
            enableShielding()
        case .shieldOff:
            disableShielding()
        }
    }

    // Turns on app shielding for the selected app tokens.
    // This is the same behavior triggered by reading focus://shield/on from a tag.
    func enableShielding() {
#if FOCUS_RESTRICTED_CAPABILITIES
        refreshAuthorizationStatus()

        // Screen Time authorization is mandatory before ManagedSettings can shield apps.
        guard isScreenTimeAuthorized else {
            statusMessage = "Authorize Screen Time before enabling app shielding."
            return
        }

        // There is nothing to shield until the user selects at least one app.
        guard hasSelectedApplications else {
            statusMessage = "Choose at least one app before enabling shielding."
            return
        }

        // This is the line that asks iOS to show the system shield over selected apps.
        store.shield.applications = selection.applicationTokens
        isShieldingEnabled = true
        statusMessage = "Shielding enabled for selected apps."
#else
        isShieldingEnabled = true
        statusMessage = "Simulator mode: Shield On command received. No real apps are blocked."
#endif
    }

    // Clears all ManagedSettings applied by this app.
    // This is the same behavior triggered by reading focus://shield/off from a tag.
    func disableShielding() {
#if FOCUS_RESTRICTED_CAPABILITIES
        store.clearAllSettings()
#endif
        isShieldingEnabled = false
#if FOCUS_RESTRICTED_CAPABILITIES
        statusMessage = "Shielding disabled."
#else
        statusMessage = "Simulator mode: Shield Off command received."
#endif
    }

    // Re-reads authorization from Apple's shared AuthorizationCenter.
    func refreshAuthorizationStatus() {
#if FOCUS_RESTRICTED_CAPABILITIES
        authorizationStatus = AuthorizationCenter.shared.authorizationStatus
#endif
    }

#if FOCUS_RESTRICTED_CAPABILITIES
    // Restores saved app-selection tokens when the app starts.
    private func loadSelection() {
        guard let data = UserDefaults.standard.data(forKey: selectionKey) else {
            return
        }

        do {
            selection = try PropertyListDecoder().decode(FamilyActivitySelection.self, from: data)
        } catch {
            // If the saved data is unreadable, remove it so future launches start cleanly.
            UserDefaults.standard.removeObject(forKey: selectionKey)
            statusMessage = "Saved app selection could not be loaded."
        }
    }
#endif
}

// The tiny command language written to and read from NFC tags.
// Raw string values are the exact text stored in the NDEF URI payload.
enum FocusCommand: String, CaseIterable, Identifiable, Sendable {
    case shieldOn = "focus://shield/on"
    case shieldOff = "focus://shield/off"

    // Identifiable lets SwiftUI use FocusCommand inside ForEach pickers.
    var id: String { rawValue }

    // Short labels shown in the command picker.
    var title: String {
        switch self {
        case .shieldOn:
            return "Shield On"
        case .shieldOff:
            return "Shield Off"
        }
    }

    // Converts raw NFC text into a known command, ignoring accidental whitespace.
    static func parse(_ value: String) -> FocusCommand? {
        let trimmedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return FocusCommand(rawValue: trimmedValue)
    }
}

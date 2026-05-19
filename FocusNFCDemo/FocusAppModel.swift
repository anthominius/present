import Foundation
import OSLog
#if FOCUS_RESTRICTED_CAPABILITIES
import FamilyControls
import ManagedSettings
#endif

struct PresentSession: Codable, Hashable, Identifiable {
    let id: UUID
    let startDate: Date
    let endDate: Date

    init(id: UUID = UUID(), startDate: Date, endDate: Date) {
        self.id = id
        self.startDate = startDate
        self.endDate = endDate
    }

    var interval: DateInterval? {
        guard endDate > startDate else {
            return nil
        }

        return DateInterval(start: startDate, end: endDate)
    }
}

struct PresentHourBlock: Hashable, Identifiable {
    let interval: DateInterval
    let isPresent: Bool

    var id: Date {
        interval.start
    }
}

// @MainActor means this object updates UI-facing state only on the main thread.
// That keeps SwiftUI screen updates predictable and avoids concurrency warnings.
@MainActor
final class FocusAppModel: ObservableObject {
    private let screenTimeLogger = Logger(
        subsystem: "com.anthonymadrazo.FocusNFCDemo",
        category: "ScreenTime"
    )

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

    @Published private(set) var presentStartedAt: Date?
    @Published private(set) var presentSessions: [PresentSession] = []

    private let presentStartedAtKey = "FocusNFCDemo.presentStartedAt"
    private let presentSessionsKey = "FocusNFCDemo.presentSessions"
    private let presentSessionRetention: TimeInterval = 14 * 24 * 60 * 60

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
        screenTimeLogger.info(
            "FocusAppModel initialized. authorizationStatus=\(self.authorizationSummary, privacy: .public), selectedApplications=\(self.selection.applicationTokens.count, privacy: .public)"
        )
#else
        screenTimeLogger.info("FocusAppModel initialized without restricted Screen Time capabilities.")
#endif
        loadPresentTracking()
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
        screenTimeLogger.info(
            "Requesting Screen Time authorization. currentStatus=\(self.authorizationSummary, privacy: .public)"
        )

        do {
            try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
            refreshAuthorizationStatus()
            statusMessage = "Screen Time authorization approved."
            screenTimeLogger.info(
                "Screen Time authorization succeeded. newStatus=\(self.authorizationSummary, privacy: .public)"
            )
        } catch {
            refreshAuthorizationStatus()
            statusMessage = "Screen Time authorization failed: \(error.localizedDescription)"
            screenTimeLogger.error(
                "Screen Time authorization failed. newStatus=\(self.authorizationSummary, privacy: .public), error=\(error.localizedDescription, privacy: .public)"
            )
        }
#else
        isShieldingEnabled = false
        statusMessage = "Simulator mode: Screen Time authorization is disabled until restricted capabilities are enabled."
        screenTimeLogger.notice("Screen Time authorization requested, but restricted capabilities are compiled out.")
#endif
    }

    func activityPickerPresentationChanged(isShowing: Bool) {
#if FOCUS_RESTRICTED_CAPABILITIES
        if isShowing {
            screenTimeLogger.info(
                "Presenting FamilyActivityPicker. authorizationStatus=\(self.authorizationSummary, privacy: .public), selectedApplicationsBefore=\(self.selection.applicationTokens.count, privacy: .public)"
            )
        } else {
            screenTimeLogger.info(
                "FamilyActivityPicker dismissed. selectedApplicationsAfter=\(self.selection.applicationTokens.count, privacy: .public)"
            )
            persistSelection()
        }
#else
        screenTimeLogger.notice(
            "FamilyActivityPicker presentation changed while restricted capabilities are compiled out. isShowing=\(isShowing, privacy: .public)"
        )
#endif
    }

    // Saves the FamilyActivitySelection after the picker closes.
    // PropertyListEncoder works because Apple's selection type conforms to Codable.
    func persistSelection() {
#if FOCUS_RESTRICTED_CAPABILITIES
        screenTimeLogger.info(
            "Persisting FamilyActivitySelection. selectedApplications=\(self.selection.applicationTokens.count, privacy: .public)"
        )

        do {
            let data = try PropertyListEncoder().encode(selection)
            UserDefaults.standard.set(data, forKey: selectionKey)
            statusMessage = selectedApplicationsSummary
            screenTimeLogger.info(
                "FamilyActivitySelection persisted. encodedBytes=\(data.count, privacy: .public)"
            )
        } catch {
            statusMessage = "Could not save selected apps: \(error.localizedDescription)"
            screenTimeLogger.error(
                "Could not persist FamilyActivitySelection. error=\(error.localizedDescription, privacy: .public)"
            )
        }
#else
        statusMessage = "Simulator mode: no app selection to save."
        screenTimeLogger.notice("Selection persistence requested, but restricted capabilities are compiled out.")
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
        screenTimeLogger.info(
            "Attempting to enable shielding. authorizationStatus=\(self.authorizationSummary, privacy: .public), selectedApplications=\(self.selection.applicationTokens.count, privacy: .public)"
        )

        // Screen Time authorization is mandatory before ManagedSettings can shield apps.
        guard isScreenTimeAuthorized else {
            statusMessage = "Authorize Screen Time before enabling app shielding."
            screenTimeLogger.warning(
                "Shielding blocked because Screen Time is not authorized. authorizationStatus=\(self.authorizationSummary, privacy: .public)"
            )
            return
        }

        // There is nothing to shield until the user selects at least one app.
        guard hasSelectedApplications else {
            statusMessage = "Choose at least one app before enabling shielding."
            screenTimeLogger.warning("Shielding blocked because no applications are selected.")
            return
        }

        // This is the line that asks iOS to show the system shield over selected apps.
        store.shield.applications = selection.applicationTokens
        isShieldingEnabled = true
        beginPresentSessionIfNeeded()
        statusMessage = "Shielding enabled for selected apps."
        screenTimeLogger.info(
            "Shielding enabled. selectedApplications=\(self.selection.applicationTokens.count, privacy: .public)"
        )
#else
        isShieldingEnabled = true
        beginPresentSessionIfNeeded()
        statusMessage = "Simulator mode: Present command received. No real apps are blocked."
        screenTimeLogger.notice("Shielding simulated because restricted capabilities are compiled out.")
#endif
    }

    // Clears all ManagedSettings applied by this app.
    // This is the same behavior triggered by reading focus://shield/off from a tag.
    func disableShielding() {
#if FOCUS_RESTRICTED_CAPABILITIES
        screenTimeLogger.info("Disabling shielding and clearing ManagedSettingsStore.")
        store.clearAllSettings()
#endif
        isShieldingEnabled = false
        endPresentSessionIfNeeded()
#if FOCUS_RESTRICTED_CAPABILITIES
        statusMessage = "Shielding disabled."
        screenTimeLogger.info("Shielding disabled.")
#else
        statusMessage = "Simulator mode: Distant command received."
        screenTimeLogger.notice("Shielding disable simulated because restricted capabilities are compiled out.")
#endif
    }

    // Re-reads authorization from Apple's shared AuthorizationCenter.
    func refreshAuthorizationStatus() {
#if FOCUS_RESTRICTED_CAPABILITIES
        let previousSummary = authorizationSummary
        authorizationStatus = AuthorizationCenter.shared.authorizationStatus
        let currentSummary = authorizationSummary

        if previousSummary != currentSummary {
            screenTimeLogger.info(
                "Screen Time authorization status changed. previous=\(previousSummary, privacy: .public), current=\(currentSummary, privacy: .public)"
            )
        } else {
            screenTimeLogger.debug(
                "Screen Time authorization status refreshed. current=\(currentSummary, privacy: .public)"
            )
        }
#endif
    }

    func activePresentDuration(at date: Date = .now) -> TimeInterval? {
        guard let presentStartedAt else {
            return nil
        }

        return max(0, date.timeIntervalSince(presentStartedAt))
    }

    var lastPresentSessionDuration: TimeInterval? {
        presentSessions
            .reversed()
            .compactMap { $0.interval?.duration }
            .first
    }

    func recentPresentSessions(now: Date = .now, lookback: TimeInterval = 24 * 60 * 60) -> [DateInterval] {
        let window = DateInterval(start: now.addingTimeInterval(-lookback), end: now)
        var intervals = presentSessions.compactMap(\.interval)

        if let presentStartedAt, presentStartedAt < now {
            intervals.append(DateInterval(start: presentStartedAt, end: now))
        }

        return intervals.compactMap { interval in
            guard interval.intersects(window) else {
                return nil
            }

            return DateInterval(start: max(interval.start, window.start), end: min(interval.end, window.end))
        }
    }

    func presentHourBlocks(now: Date = .now) -> [PresentHourBlock] {
        let calendar = Calendar.current
        let currentHour = calendar.dateInterval(of: .hour, for: now) ?? DateInterval(start: now, duration: 60 * 60)
        let presentIntervals = recentPresentSessions(now: now)

        return (0..<24).compactMap { offset in
            guard let start = calendar.date(byAdding: .hour, value: offset - 23, to: currentHour.start) else {
                return nil
            }

            let interval = DateInterval(start: start, duration: 60 * 60)
            let isPresent = presentIntervals.contains { $0.intersects(interval) }
            return PresentHourBlock(interval: interval, isPresent: isPresent)
        }
    }

    private func beginPresentSessionIfNeeded(now: Date = .now) {
        prunePresentSessions(now: now)

        if let presentStartedAt, presentStartedAt <= now {
            persistPresentTracking()
            return
        }

        presentStartedAt = now
        persistPresentTracking()
    }

    private func endPresentSessionIfNeeded(now: Date = .now) {
        guard let startDate = presentStartedAt else {
            prunePresentSessions(now: now)
            persistPresentTracking()
            return
        }

        presentStartedAt = nil

        guard startDate < now else {
            prunePresentSessions(now: now)
            persistPresentTracking()
            return
        }

        presentSessions.append(PresentSession(startDate: startDate, endDate: now))
        prunePresentSessions(now: now)
        persistPresentTracking()
    }

    private func loadPresentTracking(now: Date = .now) {
        if let startedAt = UserDefaults.standard.object(forKey: presentStartedAtKey) as? Date,
           startedAt <= now {
            presentStartedAt = startedAt
        } else {
            UserDefaults.standard.removeObject(forKey: presentStartedAtKey)
        }

        if let data = UserDefaults.standard.data(forKey: presentSessionsKey),
           let decodedSessions = try? JSONDecoder().decode([PresentSession].self, from: data) {
            presentSessions = decodedSessions.compactMap { session in
                guard session.startDate < now else {
                    return nil
                }

                let endDate = min(session.endDate, now)
                guard endDate > session.startDate else {
                    return nil
                }

                return PresentSession(id: session.id, startDate: session.startDate, endDate: endDate)
            }
            prunePresentSessions(now: now)
        } else {
            UserDefaults.standard.removeObject(forKey: presentSessionsKey)
        }

        persistPresentTracking()
    }

    private func persistPresentTracking() {
        if let presentStartedAt {
            UserDefaults.standard.set(presentStartedAt, forKey: presentStartedAtKey)
        } else {
            UserDefaults.standard.removeObject(forKey: presentStartedAtKey)
        }

        if let data = try? JSONEncoder().encode(presentSessions) {
            UserDefaults.standard.set(data, forKey: presentSessionsKey)
        }
    }

    private func prunePresentSessions(now: Date = .now) {
        let cutoff = now.addingTimeInterval(-presentSessionRetention)
        presentSessions = presentSessions.filter { session in
            guard let interval = session.interval else {
                return false
            }

            return interval.end >= cutoff && interval.start <= now
        }
    }

#if FOCUS_RESTRICTED_CAPABILITIES
    // Restores saved app-selection tokens when the app starts.
    private func loadSelection() {
        guard let data = UserDefaults.standard.data(forKey: selectionKey) else {
            screenTimeLogger.info("No saved FamilyActivitySelection found.")
            return
        }

        do {
            selection = try PropertyListDecoder().decode(FamilyActivitySelection.self, from: data)
            screenTimeLogger.info(
                "Loaded saved FamilyActivitySelection. selectedApplications=\(self.selection.applicationTokens.count, privacy: .public), encodedBytes=\(data.count, privacy: .public)"
            )
        } catch {
            // If the saved data is unreadable, remove it so future launches start cleanly.
            UserDefaults.standard.removeObject(forKey: selectionKey)
            statusMessage = "Saved app selection could not be loaded."
            screenTimeLogger.error(
                "Saved FamilyActivitySelection could not be decoded and was removed. error=\(error.localizedDescription, privacy: .public)"
            )
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
            return "Present"
        case .shieldOff:
            return "Distant"
        }
    }

    // Converts raw NFC text into a known command, ignoring accidental whitespace.
    static func parse(_ value: String) -> FocusCommand? {
        let trimmedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return FocusCommand(rawValue: trimmedValue)
    }
}

#if FOCUS_RESTRICTED_CAPABILITIES
import DeviceActivity
import FamilyControls
#endif
import OSLog
import SwiftUI

#if FOCUS_RESTRICTED_CAPABILITIES
extension DeviceActivityReport.Context {
    static let presentScreenTimeSummary = Self("Present Screen Time Summary")
}
#endif

struct ContentView: View {
    @EnvironmentObject private var model: FocusAppModel
    @StateObject private var nfc = NFCSessionManager()
    @State private var commandToWrite: FocusCommand = .shieldOn

    var body: some View {
        TabView {
            DashboardView()
                .tabItem {
                    Label("Dashboard", systemImage: "chart.bar.xaxis")
                }

            SettingsView(nfc: nfc, commandToWrite: $commandToWrite)
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
        }
        .tint(Color.presentGreen)
        .preferredColorScheme(.dark)
        .toolbarBackground(Color.presentBackground, for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
#if FOCUS_RESTRICTED_CAPABILITIES
        .familyActivityPicker(isPresented: $model.showingActivityPicker, selection: $model.selection)
        .onChange(of: model.showingActivityPicker) { isShowing in
            model.activityPickerPresentationChanged(isShowing: isShowing)
        }
#endif
        .task {
            model.refreshAuthorizationStatus()
        }
    }
}

private struct DashboardView: View {
    @EnvironmentObject private var model: FocusAppModel

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header
                    activePresentCard
                    ScreenTimeReportCard()
                    presentTimelineCard
                }
                .padding(20)
            }
            .background(Color.presentBackground.ignoresSafeArea())
            .navigationTitle("Present")
            .toolbarBackground(Color.presentBackground, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Dashboard")
                .font(.largeTitle.weight(.bold))
                .foregroundStyle(Color.presentInk)
            Text("A quiet view of focus time, screen time, and the hours you stayed present.")
                .font(.subheadline)
                .foregroundStyle(Color.presentMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var activePresentCard: some View {
        MetricPanel {
            TimelineView(.periodic(from: .now, by: 1)) { timeline in
                VStack(alignment: .leading, spacing: 16) {
                    HStack(alignment: .firstTextBaseline) {
                        Label("Present Now", systemImage: "shield.lefthalf.filled")
                            .font(.headline)
                            .foregroundStyle(Color.presentInk)
                        Spacer()
                        StatusPill(text: model.isShieldingEnabled ? "Present" : "Distant", isActive: model.isShieldingEnabled)
                    }

                    Text(elapsedText(at: timeline.date))
                        .font(.system(size: 44, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(Color.presentInk)
                        .minimumScaleFactor(0.7)

                    HStack(spacing: 18) {
                        TimeSummary(label: summaryLabel, value: summaryText)
                        TimeSummary(label: "Checked", value: timeline.date.formatted(date: .omitted, time: .shortened))
                    }
                }
            }
        }
    }

    private var summaryLabel: String {
        model.isShieldingEnabled ? "Started" : "Last Session"
    }

    private var summaryText: String {
        guard let presentStartedAt = model.presentStartedAt else {
            guard let duration = model.lastPresentSessionDuration else {
                return "No sessions yet"
            }

            return durationText(duration)
        }

        return presentStartedAt.formatted(date: .omitted, time: .shortened)
    }

    private var presentTimelineCard: some View {
        MetricPanel {
            TimelineView(.periodic(from: .now, by: 60)) { timeline in
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        Label("Last 24 Hours", systemImage: "clock")
                            .font(.headline)
                            .foregroundStyle(Color.presentInk)
                        Text("Highlighted hours mark time spent Present.")
                            .font(.caption)
                            .foregroundStyle(Color.presentMuted)
                    }

                    PresentTimeline(blocks: model.presentHourBlocks(now: timeline.date))

                    HStack {
                        Text(model.presentHourBlocks(now: timeline.date).first?.interval.start.formatted(date: .omitted, time: .shortened) ?? "")
                        Spacer()
                        Text("Now")
                    }
                    .font(.caption2)
                    .foregroundStyle(Color.presentMuted)
                }
            }
        }
    }

    private func elapsedText(at date: Date) -> String {
        guard let duration = model.activePresentDuration(at: date) else {
            return "00:00:00"
        }

        let totalSeconds = max(0, Int(duration.rounded(.down)))
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }

    private func durationText(_ duration: TimeInterval) -> String {
        let totalSeconds = max(0, Int(duration.rounded(.down)))
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60

        if hours > 0 {
            return String(format: "%dh %02dm", hours, minutes)
        }

        return String(format: "%02d:%02d", minutes, seconds)
    }
}

private struct ScreenTimeReportCard: View {
#if FOCUS_RESTRICTED_CAPABILITIES
    @EnvironmentObject private var model: FocusAppModel

    private let reportLogger = Logger(
        subsystem: "com.anthonymadrazo.FocusNFCDemo",
        category: "ScreenTimeReport"
    )
#endif

    var body: some View {
        MetricPanel {
            VStack(alignment: .leading, spacing: 14) {
                Label("Screen Time", systemImage: "iphone")
                    .font(.headline)
                    .foregroundStyle(Color.presentInk)

#if FOCUS_RESTRICTED_CAPABILITIES
                reportContent
#else
                VStack(alignment: .leading, spacing: 8) {
                    Text("Screen Time data unavailable")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.presentInk)
                    Text("Use a restricted build with Screen Time authorization to show daily and weekly averages.")
                        .font(.caption)
                        .foregroundStyle(Color.presentMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
#endif
            }
        }
#if FOCUS_RESTRICTED_CAPABILITIES
        .onAppear {
            reportLogger.info(
                "ScreenTimeReportCard appeared. authorizationStatus=\(model.authorizationSummary, privacy: .public)"
            )
        }
#endif
    }

#if FOCUS_RESTRICTED_CAPABILITIES
    @ViewBuilder
    private var reportContent: some View {
        switch model.authorizationStatus {
        case .approvedWithDataAccess:
            screenTimeReport
        case .approved:
            if requiresExplicitReportDataAccess {
                reportStatusMessage(
                    title: "Screen Time data access needed",
                    message: "This install is approved for Screen Time controls, but not for App and Website Usage data. Confirm the app and report extension are signed with that capability, then authorize again."
                )
            } else {
                screenTimeReport
            }
        case .denied:
            reportStatusMessage(
                title: "Screen Time access denied",
                message: "Approve Screen Time access in Settings to show daily and weekly usage."
            )
        case .notDetermined:
            reportStatusMessage(
                title: "Screen Time not authorized",
                message: "Authorize Screen Time to show daily and weekly usage."
            )
        @unknown default:
            reportStatusMessage(
                title: "Screen Time status unknown",
                message: "The system returned an authorization state this app does not recognize."
            )
        }
    }

    private var screenTimeReport: some View {
        DeviceActivityReport(.presentScreenTimeSummary, filter: reportFilter)
            .frame(minHeight: 132)
    }

    private func reportStatusMessage(title: String, message: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.presentInk)
            Text(message)
                .font(.caption)
                .foregroundStyle(Color.presentMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, minHeight: 132, alignment: .leading)
    }

    private var requiresExplicitReportDataAccess: Bool {
        if #available(iOS 26.4, *) {
            return true
        }

        return false
    }

    private var reportFilter: DeviceActivityFilter {
        let calendar = Calendar.current
        let now = Date()
        let today = calendar.startOfDay(for: now)
        let start = calendar.date(byAdding: .day, value: -13, to: today) ?? today
        return DeviceActivityFilter(segment: .daily(during: DateInterval(start: start, end: now)), devices: .all)
    }
#endif
}

private struct SettingsView: View {
    @EnvironmentObject private var model: FocusAppModel
    @ObservedObject var nfc: NFCSessionManager
    @Binding var commandToWrite: FocusCommand

    var body: some View {
        NavigationStack {
            Form {
                Section("Status") {
                    StatusRow(title: "Screen Time", value: model.authorizationSummary)
                    StatusRow(title: "NFC", value: nfc.isReadingAvailable ? "Available" : "Unavailable")
                    StatusRow(title: "State", value: model.isShieldingEnabled ? "Present" : "Distant")
                    Text(model.statusMessage)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    Text(nfc.statusMessage)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }

                Section("Apps") {
                    Text(model.selectedApplicationsSummary)
#if FOCUS_RESTRICTED_CAPABILITIES
                    Button("Authorize Screen Time") {
                        Task {
                            await model.requestAuthorization()
                        }
                    }
                    Button("Choose Apps") {
                        model.showingActivityPicker = true
                    }
#else
                    Text("Restricted APIs are compiled out in this build configuration.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
#endif
                }

                Section("Shield") {
                    Button("Become Present") {
                        model.handle(.shieldOn)
                    }

                    Button("Go Distant", role: .destructive) {
                        model.handle(.shieldOff)
                    }
                }

                Section("NFC Tag") {
                    Picker("Command", selection: $commandToWrite) {
                        ForEach(FocusCommand.allCases) { command in
                            Text(command.title).tag(command)
                        }
                    }

                    Button("Write Tag") {
                        nfc.write(commandToWrite)
                    }
                    .disabled(!nfc.isReadingAvailable)

                    Button("Scan Tag") {
                        nfc.scan { command in
                            model.handle(command)
                        }
                    }
                    .disabled(!nfc.isReadingAvailable)
                }
            }
            .navigationTitle("Settings")
        }
    }
}

private struct MetricPanel<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.presentPanel)
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color.presentBorder, lineWidth: 1)
            }
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .shadow(color: Color.presentGreen.opacity(0.08), radius: 18, x: 0, y: 10)
    }
}

private struct StatusPill: View {
    let text: String
    let isActive: Bool

    var body: some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .foregroundStyle(isActive ? Color.presentGreen : Color.presentAmber)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background((isActive ? Color.presentGreen : Color.presentAmber).opacity(0.12))
            .clipShape(Capsule())
    }
}

private struct TimeSummary: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundStyle(Color.presentMuted)
            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.presentInk)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct PresentTimeline: View {
    let blocks: [PresentHourBlock]

    var body: some View {
        HStack(spacing: 3) {
            ForEach(blocks) { block in
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(block.isPresent ? Color.presentGreen : Color.presentAmber.opacity(0.22))
                    .frame(height: block.isPresent ? 42 : 30)
                    .accessibilityLabel(blockAccessibilityLabel(block))
            }
        }
        .frame(height: 46)
    }

    private func blockAccessibilityLabel(_ block: PresentHourBlock) -> String {
        let hour = block.interval.start.formatted(date: .omitted, time: .shortened)
        return block.isPresent ? "Present at \(hour)" : "Not present at \(hour)"
    }
}

private struct StatusRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            Text(value)
                .foregroundStyle(.secondary)
        }
    }
}

private extension Color {
    static let presentBackground = Color(red: 0.04, green: 0.05, blue: 0.045)
    static let presentPanel = Color(red: 0.095, green: 0.105, blue: 0.095)
    static let presentBorder = Color(red: 0.22, green: 0.25, blue: 0.21).opacity(0.75)
    static let presentInk = Color(red: 0.96, green: 0.95, blue: 0.90)
    static let presentMuted = Color(red: 0.70, green: 0.69, blue: 0.62)
    static let presentGreen = Color(red: 0.36, green: 0.82, blue: 0.48)
    static let presentAmber = Color(red: 0.95, green: 0.68, blue: 0.24)
}

#Preview {
    ContentView()
        .environmentObject(FocusAppModel())
}

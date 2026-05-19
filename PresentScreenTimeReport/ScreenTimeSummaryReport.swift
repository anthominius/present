import DeviceActivity
import ExtensionKit
import OSLog
import SwiftUI

extension DeviceActivityReport.Context {
    static let presentScreenTimeSummary = Self("Present Screen Time Summary")
}

struct ScreenTimeSummaryConfiguration {
    let dailyDuration: TimeInterval
    let dailyDelta: TimeInterval
    let weeklyAverageDuration: TimeInterval
    let weeklyAverageDelta: TimeInterval
    let hasData: Bool
}

struct ScreenTimeSummaryReport: DeviceActivityReportScene {
    let context: DeviceActivityReport.Context = .presentScreenTimeSummary
    let content: (ScreenTimeSummaryConfiguration) -> ScreenTimeSummaryView

    private let reportLogger = Logger(
        subsystem: "com.anthonymadrazo.FocusNFCDemo",
        category: "ScreenTimeReport"
    )

    func makeConfiguration(representing data: DeviceActivityResults<DeviceActivityData>) async -> ScreenTimeSummaryConfiguration {
        let calendar = Calendar.current
        let now = Date()
        let today = calendar.startOfDay(for: now)
        let durationsByDay = await dailyDurations(from: data, calendar: calendar, now: now)
        reportLogger.info(
            "DeviceActivityReport makeConfiguration. dayCount=\(durationsByDay.count, privacy: .public), isEmpty=\(durationsByDay.isEmpty, privacy: .public)"
        )

        let dailyDuration = durationsByDay[today, default: 0]
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today) ?? today
        let yesterdayDuration = durationsByDay[yesterday, default: 0]
        let weeklyAverage = averageDuration(inOffsets: 0..<7, from: today, calendar: calendar, durationsByDay: durationsByDay)
        let previousWeeklyAverage = averageDuration(inOffsets: 7..<14, from: today, calendar: calendar, durationsByDay: durationsByDay)

        return ScreenTimeSummaryConfiguration(
            dailyDuration: dailyDuration,
            dailyDelta: dailyDuration - yesterdayDuration,
            weeklyAverageDuration: weeklyAverage,
            weeklyAverageDelta: weeklyAverage - previousWeeklyAverage,
            hasData: !durationsByDay.isEmpty
        )
    }

    private func dailyDurations(
        from data: DeviceActivityResults<DeviceActivityData>,
        calendar: Calendar,
        now: Date
    ) async -> [Date: TimeInterval] {
        await data
            .flatMap { $0.activitySegments }
            .reduce(into: [Date: TimeInterval]()) { partialResult, segment in
                guard segment.dateInterval.start <= now else {
                    return
                }

                let day = calendar.startOfDay(for: segment.dateInterval.start)
                partialResult[day, default: 0] += max(0, segment.totalActivityDuration)
            }
    }

    private func averageDuration(
        inOffsets offsets: Range<Int>,
        from today: Date,
        calendar: Calendar,
        durationsByDay: [Date: TimeInterval]
    ) -> TimeInterval {
        let total = offsets.reduce(0) { partialResult, offset in
            guard let day = calendar.date(byAdding: .day, value: -offset, to: today) else {
                return partialResult
            }

            return partialResult + durationsByDay[day, default: 0]
        }

        return total / TimeInterval(offsets.count)
    }
}

struct ScreenTimeSummaryView: View {
    let configuration: ScreenTimeSummaryConfiguration

    var body: some View {
        VStack(spacing: 12) {
            if configuration.hasData {
                ScreenTimeStatRow(
                    title: "Today",
                    duration: configuration.dailyDuration,
                    delta: configuration.dailyDelta
                )
                ScreenTimeStatRow(
                    title: "7-Day Average",
                    duration: configuration.weeklyAverageDuration,
                    delta: configuration.weeklyAverageDelta
                )
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Text("No Screen Time data yet")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.presentInk)
                    Text("Data appears here after Screen Time access is approved and the system has usage to report.")
                        .font(.caption)
                        .foregroundStyle(Color.presentMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}

private struct ScreenTimeStatRow: View {
    let title: String
    let duration: TimeInterval
    let delta: TimeInterval

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(Color.presentMuted)
                Text(durationText(duration))
                    .font(.title3.weight(.bold))
                    .foregroundStyle(Color.presentInk)
                    .monospacedDigit()
            }

            Spacer(minLength: 12)

            Text(deltaText(delta))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(delta <= 0 ? Color.presentGreen : Color.presentAmber)
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func durationText(_ duration: TimeInterval) -> String {
        let minutes = max(0, Int((duration / 60).rounded()))
        let hours = minutes / 60
        let remainingMinutes = minutes % 60

        if hours > 0 {
            return "\(hours)h \(remainingMinutes)m"
        }

        return "\(remainingMinutes)m"
    }

    private func deltaText(_ delta: TimeInterval) -> String {
        let minutes = abs(Int((delta / 60).rounded()))
        let prefix = delta <= 0 ? "-" : "+"
        return "\(prefix)\(minutes)m"
    }
}

private extension Color {
    static let presentInk = Color(red: 0.96, green: 0.95, blue: 0.90)
    static let presentMuted = Color(red: 0.70, green: 0.69, blue: 0.62)
    static let presentGreen = Color(red: 0.36, green: 0.82, blue: 0.48)
    static let presentAmber = Color(red: 0.95, green: 0.68, blue: 0.24)
}

import DeviceActivity
import ExtensionKit
import SwiftUI

@main
struct PresentScreenTimeReport: DeviceActivityReportExtension {
    var body: some DeviceActivityReportScene {
        ScreenTimeSummaryReport { configuration in
            ScreenTimeSummaryView(configuration: configuration)
        }
    }
}

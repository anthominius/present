import SwiftUI

// The @main attribute marks this struct as the app's starting point.
// SwiftUI calls the body below when the app launches.
@main
struct FocusNFCDemoApp: App {
    // @StateObject creates one long-lived model for the whole app session.
    // Views can read and update this shared state through environmentObject.
    @StateObject private var model = FocusAppModel()

    // A Scene describes what windows or screens this app can show.
    // WindowGroup is the normal single-app-window setup for an iPhone app.
    var body: some Scene {
        WindowGroup {
            // ContentView is the first screen the user sees.
            // The model is injected so child views can access NFC/app-shielding state.
            ContentView()
                .environmentObject(model)
                .onOpenURL { url in
                    guard let command = FocusCommand.parse(url.absoluteString) else {
                        model.statusMessage = "Opened unsupported Focus URL: \(url.absoluteString)"
                        return
                    }

                    switch command {
                    case .shieldOn:
                        model.handle(command)
                    case .shieldOff:
                        model.statusMessage = "Open the app or scan a trusted tag to disable shielding."
                    }
                }
        }
    }
}

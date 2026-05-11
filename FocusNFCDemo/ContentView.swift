#if FOCUS_RESTRICTED_CAPABILITIES
import FamilyControls
#endif
import SwiftUI

// Main screen for the demo.
// It combines app-selection, NFC read/write, and no-tag simulation controls.
struct ContentView: View {
    // Reads the shared app model created in FocusNFCDemoApp.
    @EnvironmentObject private var model: FocusAppModel

    // Owns NFC sessions for this screen.
    @StateObject private var nfc = NFCSessionManager()

    // Tracks which command the "Write Tag" button should put on a card.
    @State private var commandToWrite: FocusCommand = .shieldOn

    // SwiftUI recomputes body whenever relevant @State or @Published data changes.
    var body: some View {
        // NavigationStack gives the form a title and standard iOS navigation behavior.
        NavigationStack {
            contentForm
                .navigationTitle("Present")
#if FOCUS_RESTRICTED_CAPABILITIES
                // Presents Apple's system app picker. The picker writes selected app tokens
                // into model.selection without exposing app names to this app.
                .familyActivityPicker(isPresented: $model.showingActivityPicker, selection: $model.selection)
                // When the picker closes, save the latest selection.
                .onChange(of: model.showingActivityPicker) { isShowing in
                    if !isShowing {
                        model.persistSelection()
                    }
                }
#endif
                // Refresh authorization when the screen appears.
                .task {
                    model.refreshAuthorizationStatus()
                }
        }
    }

    // The main form is split out so the restricted-only modifiers above can be
    // conditionally compiled without duplicating the whole screen.
    private var contentForm: some View {
            // Form gives us a familiar iOS Settings-style layout.
            Form {
                // Shows the current permission, NFC, and shielding state.
                Section("Status") {
                    StatusRow(title: "Screen Time", value: model.authorizationSummary)
                    StatusRow(title: "NFC", value: nfc.isReadingAvailable ? "Available" : "Unavailable")
                    StatusRow(title: "Shielding", value: model.isShieldingEnabled ? "On" : "Off")
                    Text(model.statusMessage)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    Text(nfc.statusMessage)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }

                // Lets the user authorize Screen Time and choose which apps can be shielded.
                Section("Apps") {
                    Text(model.selectedApplicationsSummary)
#if FOCUS_RESTRICTED_CAPABILITIES
                    Button("Authorize Screen Time") {
                        // requestAuthorization is async because iOS may show a permission prompt.
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

                // Writes an NFC command to a tag or scans a tag for a command.
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

                // Lets you test the app-shielding path before your NFC tag arrives.
                Section("Manual Controls") {
                    Button("Simulate Shield On") {
                        model.handle(.shieldOn)
                    }

                    Button("Simulate Shield Off", role: .destructive) {
                        model.handle(.shieldOff)
                    }
                }
            }
    }
}

// Small reusable row for two-column status values.
private struct StatusRow: View {
    let title: String
    let value: String

    // Aligns a label on the left and its current value on the right.
    var body: some View {
        HStack {
            Text(title)
            Spacer()
            Text(value)
                .foregroundStyle(.secondary)
        }
    }
}

// Xcode canvas preview.
// Hardware features such as NFC and real app shielding still need a physical iPhone.
#Preview {
    ContentView()
        .environmentObject(FocusAppModel())
}

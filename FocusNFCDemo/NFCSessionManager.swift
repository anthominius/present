import CoreNFC
import Foundation

// CoreNFC completion handlers are imported as @Sendable, but NFC sessions and tags
// are framework-owned reference types that do not conform to Sendable. These wrappers
// make the few captures inside CoreNFC's own callback chain explicit.
private struct NFCSessionReference: @unchecked Sendable {
    let value: NFCNDEFReaderSession
}

private struct NFCTagReference: @unchecked Sendable {
    let value: NFCNDEFTag
}

// This object owns Core NFC sessions.
// It is separate from FocusAppModel so NFC hardware details stay out of app-shielding logic.
@MainActor
final class NFCSessionManager: NSObject, ObservableObject {
    // Status text shown in the UI for read/write progress and errors.
    @Published var statusMessage = "Ready"

    // Core NFC reports false on unsupported devices and in many simulator contexts.
    @Published var isReadingAvailable = NFCNDEFReaderSession.readingAvailable

    // Keeping a strong reference is important.
    // If this property were removed, the NFC session could be deallocated too early.
    private var session: NFCNDEFReaderSession?

    // Non-nil only during a write session; nil during a read session.
    private var pendingWriteCommand: FocusCommand?

    // Callback fired when a scan finds a valid FocusCommand.
    private var onReadCommand: (@MainActor (FocusCommand) -> Void)?

    // Prevents the normal session-ending callback from replacing useful success text.
    private var didFinishSessionSuccessfully = false

    // Starts an in-app NFC read session.
    // iOS shows a system scan sheet, then calls delegate methods when it reads a tag.
    func scan(onCommand: @escaping @MainActor (FocusCommand) -> Void) {
        guard NFCNDEFReaderSession.readingAvailable else {
            statusMessage = "NFC reading is not available on this device."
            return
        }

        pendingWriteCommand = nil
        onReadCommand = onCommand
        didFinishSessionSuccessfully = false

        let session = NFCNDEFReaderSession(delegate: self, queue: .main, invalidateAfterFirstRead: false)
        session.alertMessage = "Hold your iPhone near a Present tag."
        self.session = session
        session.begin()
    }

    // Starts an in-app NFC write session for the selected command.
    // The user must hold the phone near one writable NDEF-compatible tag.
    func write(_ command: FocusCommand) {
        guard NFCNDEFReaderSession.readingAvailable else {
            statusMessage = "NFC writing is not available on this device."
            return
        }

        pendingWriteCommand = command
        onReadCommand = nil
        didFinishSessionSuccessfully = false

        let session = NFCNDEFReaderSession(delegate: self, queue: .main, invalidateAfterFirstRead: false)
        session.alertMessage = "Hold your iPhone near a writable NDEF tag."
        self.session = session
        session.begin()
    }
}

// Core NFC uses delegate callbacks instead of async/await.
// These methods are called by iOS as the NFC session changes state.
extension NFCSessionManager: NFCNDEFReaderSessionDelegate {
    // Called when the NFC scan sheet is active and ready.
    nonisolated func readerSessionDidBecomeActive(_ session: NFCNDEFReaderSession) {
        // Sessions are created with queue: .main, so delegate callbacks can re-enter
        // the manager's MainActor state without carrying NFC objects through a Task.
        MainActor.assumeIsolated {
            statusMessage = "NFC session active."
        }
    }

    // Called during read sessions after iOS reads one or more NDEF messages.
    nonisolated func readerSession(_ session: NFCNDEFReaderSession, didDetectNDEFs messages: [NFCNDEFMessage]) {
        // Flatten all records from all messages, decode each as text/URI, and keep
        // the first value that matches our tiny command language.
        let decodedValues = messages.flatMap(Self.commandStrings(from:))
        let command = decodedValues.compactMap(FocusCommand.parse(_:)).first

        MainActor.assumeIsolated {
            guard let command else {
                statusMessage = Self.invalidTagStatus(decodedValues: decodedValues)
                return
            }

            didFinishSessionSuccessfully = true
            statusMessage = "Read \(command.rawValue)."
            onReadCommand?(command)
        }
    }

    // Called during write sessions when iOS detects one or more nearby tags.
    nonisolated func readerSession(_ session: NFCNDEFReaderSession, didDetect tags: [NFCNDEFTag]) {
        let sessionReference = NFCSessionReference(value: session)
        let tagCount = tags.count
        let tagReference = tags.first.map(NFCTagReference.init(value:))

        MainActor.assumeIsolated {
            guard tagCount == 1, let tagReference else {
                sessionReference.value.alertMessage = "More than one tag detected. Keep only one tag near the phone."
                restartPolling(in: sessionReference.value)
                return
            }

            if let pendingWriteCommand {
                write(pendingWriteCommand, to: tagReference.value, in: sessionReference.value)
            } else {
                read(from: tagReference.value, in: sessionReference.value)
            }
        }
    }

    // Called when the user cancels, a write completes, or iOS ends the NFC session.
    nonisolated func readerSession(_ session: NFCNDEFReaderSession, didInvalidateWithError error: Error) {
        MainActor.assumeIsolated {
            if didFinishSessionSuccessfully {
                // Keep the more useful read/write success message already shown.
            } else if let readerError = error as? NFCReaderError,
                      readerError.code == .readerSessionInvalidationErrorUserCanceled {
                statusMessage = "NFC session cancelled."
            } else {
                statusMessage = "NFC session ended: \(error.localizedDescription)"
            }

            self.session = nil
            pendingWriteCommand = nil
            didFinishSessionSuccessfully = false
        }
    }

    // Gives the user a moment to move extra tags away before polling starts again.
    private func restartPolling(in session: NFCNDEFReaderSession) {
        let sessionReference = NFCSessionReference(value: session)

        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(500)) { [sessionReference] in
            sessionReference.value.restartPolling()
        }
    }

    // Connects to one tag and reads its NDEF message explicitly.
    private func read(from tag: NFCNDEFTag, in session: NFCNDEFReaderSession) {
        let sessionReference = NFCSessionReference(value: session)
        let tagReference = NFCTagReference(value: tag)

        session.connect(to: tag) { [weak self, sessionReference, tagReference] error in
            guard error == nil else {
                sessionReference.value.alertMessage = "Unable to connect to the tag."
                sessionReference.value.invalidate()
                return
            }

            tagReference.value.queryNDEFStatus { [weak self, sessionReference, tagReference] status, _, error in
                guard error == nil else {
                    sessionReference.value.alertMessage = "Unable to inspect the tag."
                    sessionReference.value.invalidate()
                    return
                }

                guard status != .notSupported else {
                    sessionReference.value.alertMessage = "This tag is not NDEF-compatible."
                    sessionReference.value.invalidate()
                    return
                }

                tagReference.value.readNDEF { [weak self, sessionReference] message, error in
                    guard error == nil, let message else {
                        sessionReference.value.alertMessage = "Unable to read the tag."
                        sessionReference.value.invalidate()
                        return
                    }

                    let decodedValues = Self.commandStrings(from: message)
                    let command = decodedValues.compactMap(FocusCommand.parse(_:)).first

                    guard let command else {
                        let status = Self.invalidTagStatus(decodedValues: decodedValues)
                        sessionReference.value.alertMessage = status
                        sessionReference.value.invalidate()

                        Task { @MainActor [weak self, status] in
                            self?.statusMessage = status
                        }
                        return
                    }

                    sessionReference.value.alertMessage = "Read \(command.rawValue)."

                    Task { @MainActor [weak self, command] in
                        self?.didFinishSessionSuccessfully = true
                        self?.statusMessage = "Read \(command.rawValue)."
                        self?.onReadCommand?(command)
                        sessionReference.value.invalidate()
                    }
                }
            }
        }
    }

    // Connects to one tag, confirms it is writable, and writes the command as NDEF.
    private func write(_ command: FocusCommand, to tag: NFCNDEFTag, in session: NFCNDEFReaderSession) {
        let sessionReference = NFCSessionReference(value: session)
        let tagReference = NFCTagReference(value: tag)

        session.connect(to: tag) { [sessionReference, tagReference, command] error in
            guard error == nil else {
                sessionReference.value.alertMessage = "Unable to connect to the tag."
                sessionReference.value.invalidate()
                return
            }

            tagReference.value.queryNDEFStatus { [sessionReference, tagReference, command] status, capacity, error in
                guard error == nil else {
                    sessionReference.value.alertMessage = "Unable to inspect the tag."
                    sessionReference.value.invalidate()
                    return
                }

                // Only read-write NDEF tags can be updated by this demo.
                guard status == .readWrite else {
                    sessionReference.value.alertMessage = status == .readOnly ? "This tag is read-only." : "This tag is not NDEF-compatible."
                    sessionReference.value.invalidate()
                    return
                }

                // Store the command as a URI payload because it is compact and easy to inspect.
                guard let payload = NFCNDEFPayload.wellKnownTypeURIPayload(string: command.rawValue) else {
                    sessionReference.value.alertMessage = "Could not prepare the NFC payload."
                    sessionReference.value.invalidate()
                    return
                }

                let message = NFCNDEFMessage(records: [payload])

                // NFC tags have tiny storage capacities, so check before writing.
                guard message.length <= capacity else {
                    sessionReference.value.alertMessage = "The command is too large for this tag."
                    sessionReference.value.invalidate()
                    return
                }

                // This is the actual write to the physical NFC tag.
                tagReference.value.writeNDEF(message) { [weak self, sessionReference, command] error in
                    let didWrite = error == nil

                    if let error {
                        sessionReference.value.alertMessage = "Write failed: \(error.localizedDescription)"
                    } else {
                        sessionReference.value.alertMessage = "Wrote \(command.rawValue)."
                    }

                    Task { @MainActor [weak self, didWrite, command] in
                        self?.didFinishSessionSuccessfully = didWrite
                        self?.statusMessage = didWrite ? "Wrote \(command.rawValue)." : "Write failed."
                        self?.pendingWriteCommand = nil
                        sessionReference.value.invalidate()
                    }
                }
            }
        }
    }

    private nonisolated static func commandStrings(from message: NFCNDEFMessage) -> [String] {
        message.records.compactMap(commandString(from:))
    }

    // Decodes a single NDEF record into a Swift String.
    // The app accepts URI records, text records, or raw UTF-8 as a convenience.
    private nonisolated static func commandString(from payload: NFCNDEFPayload) -> String? {
        if let uri = payload.wellKnownTypeURIPayload()?.absoluteString {
            return uri
        }

        if let text = payload.wellKnownTypeTextPayload().0 {
            return text
        }

        return String(data: payload.payload, encoding: .utf8)
    }

    private nonisolated static func invalidTagStatus(decodedValues: [String]) -> String {
        guard !decodedValues.isEmpty else {
            return "Tag did not contain readable text or URI data."
        }

        let values = decodedValues.joined(separator: ", ")
        return "Tag data is not a Present command: \(values)"
    }
}

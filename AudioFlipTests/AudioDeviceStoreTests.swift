import XCTest
@testable import AudioFlip

@MainActor
final class AudioDeviceStoreTests: XCTestCase {
    func testLoadsAvailableInputAndOutputDevicesAndCurrentDefaults() {
        let manager = FakeAudioDeviceManager(snapshot: FakeAudioDeviceManager.standard)
        let store = AudioDeviceStore(manager: manager)

        XCTAssertEqual(store.inputs.map(\.name), ["Built-in Microphone", "USB Microphone"])
        XCTAssertEqual(store.outputs.map(\.name), ["Built-in Speakers", "Display Audio"])
        XCTAssertEqual(store.selectedInputID, FakeAudioDeviceManager.microphone.id)
        XCTAssertEqual(store.selectedOutputID, FakeAudioDeviceManager.speakers.id)
        XCTAssertTrue(store.isSelected(FakeAudioDeviceManager.speakers.id, for: .output))
    }

    func testSelectingInputAndOutputChangesSystemDefaults() {
        let manager = FakeAudioDeviceManager(snapshot: FakeAudioDeviceManager.standard)
        let store = AudioDeviceStore(manager: manager)

        store.select(FakeAudioDeviceManager.usbMicrophone.id, for: .input)
        store.select(FakeAudioDeviceManager.display.id, for: .output)

        XCTAssertEqual(store.selectedInputID, FakeAudioDeviceManager.usbMicrophone.id)
        XCTAssertEqual(store.selectedOutputID, FakeAudioDeviceManager.display.id)
        XCTAssertEqual(manager.setOperations, [
            .init(id: FakeAudioDeviceManager.usbMicrophone.id, kind: .input),
            .init(id: FakeAudioDeviceManager.display.id, kind: .output)
        ])
        XCTAssertNil(store.errorMessage)
    }

    func testDeviceAppearingAndDisappearingRefreshesMenu() async {
        let manager = FakeAudioDeviceManager(snapshot: FakeAudioDeviceManager.standard)
        let store = AudioDeviceStore(manager: manager)
        let newSpeaker = AudioDevice(id: AudioDeviceID(rawValue: 5), name: "USB Speakers", supportedKinds: [.output])

        manager.snapshotValue = AudioDeviceSnapshot(
            devices: FakeAudioDeviceManager.standard.devices + [newSpeaker],
            defaultInputID: FakeAudioDeviceManager.standard.defaultInputID,
            defaultOutputID: FakeAudioDeviceManager.standard.defaultOutputID
        )
        manager.sendChange()
        await Task.yield()

        XCTAssertTrue(store.outputs.contains(newSpeaker))

        manager.snapshotValue = FakeAudioDeviceManager.standard
        manager.sendChange()
        await Task.yield()

        XCTAssertFalse(store.outputs.contains(newSpeaker))
    }

    func testSelectedDeviceDisappearingClearsCurrentSelection() async {
        let manager = FakeAudioDeviceManager(snapshot: FakeAudioDeviceManager.standard)
        let store = AudioDeviceStore(manager: manager)
        manager.snapshotValue = AudioDeviceSnapshot(
            devices: [FakeAudioDeviceManager.usbMicrophone, FakeAudioDeviceManager.display],
            defaultInputID: FakeAudioDeviceManager.usbMicrophone.id,
            defaultOutputID: FakeAudioDeviceManager.display.id
        )

        manager.sendChange()
        await Task.yield()

        XCTAssertFalse(store.outputs.contains(FakeAudioDeviceManager.speakers))
        XCTAssertEqual(store.selectedOutputID, FakeAudioDeviceManager.display.id)
        XCTAssertFalse(store.isSelected(FakeAudioDeviceManager.speakers.id, for: .output))
    }

    func testExternalDefaultDeviceChangeUpdatesSelection() async {
        let manager = FakeAudioDeviceManager(snapshot: FakeAudioDeviceManager.standard)
        let store = AudioDeviceStore(manager: manager)
        manager.snapshotValue = AudioDeviceSnapshot(
            devices: FakeAudioDeviceManager.standard.devices,
            defaultInputID: FakeAudioDeviceManager.usbMicrophone.id,
            defaultOutputID: FakeAudioDeviceManager.display.id
        )

        manager.sendChange()
        await Task.yield()

        XCTAssertEqual(store.selectedInputID, FakeAudioDeviceManager.usbMicrophone.id)
        XCTAssertEqual(store.selectedOutputID, FakeAudioDeviceManager.display.id)
    }

    func testOperationFailureIsShownAndLaterChangeRecovers() async {
        let manager = FakeAudioDeviceManager(snapshot: FakeAudioDeviceManager.standard)
        let store = AudioDeviceStore(manager: manager)
        manager.setError = FakeError.operationFailed

        store.select(FakeAudioDeviceManager.usbMicrophone.id, for: .input)

        XCTAssertEqual(store.errorMessage, "The fake CoreAudio operation failed.")
        XCTAssertEqual(store.selectedInputID, FakeAudioDeviceManager.microphone.id)

        manager.setError = nil
        manager.snapshotValue = AudioDeviceSnapshot(
            devices: FakeAudioDeviceManager.standard.devices,
            defaultInputID: FakeAudioDeviceManager.usbMicrophone.id,
            defaultOutputID: FakeAudioDeviceManager.speakers.id
        )
        manager.sendChange()
        await Task.yield()

        XCTAssertNil(store.errorMessage)
        XCTAssertEqual(store.selectedInputID, FakeAudioDeviceManager.usbMicrophone.id)
    }

    func testSnapshotFailureKeepsLastKnownDevicesAndLaterRefreshRecovers() async {
        let manager = FakeAudioDeviceManager(snapshot: FakeAudioDeviceManager.standard)
        let store = AudioDeviceStore(manager: manager)
        manager.snapshotError = FakeError.operationFailed

        manager.sendChange()
        await Task.yield()

        XCTAssertEqual(store.outputs.count, 2)
        XCTAssertEqual(store.errorMessage, "The fake CoreAudio operation failed.")

        manager.snapshotError = nil
        manager.snapshotValue = FakeAudioDeviceManager.standard
        manager.sendChange()
        await Task.yield()

        XCTAssertNil(store.errorMessage)
        XCTAssertEqual(store.outputs.count, 2)
    }
}

private final class FakeAudioDeviceManager: AudioDeviceManaging {
    struct SetOperation: Equatable {
        let id: AudioDeviceID
        let kind: AudioDeviceKind
    }

    static let microphone = AudioDevice(id: AudioDeviceID(rawValue: 1), name: "Built-in Microphone", supportedKinds: [.input])
    static let speakers = AudioDevice(id: AudioDeviceID(rawValue: 2), name: "Built-in Speakers", supportedKinds: [.output])
    static let usbMicrophone = AudioDevice(id: AudioDeviceID(rawValue: 3), name: "USB Microphone", supportedKinds: [.input])
    static let display = AudioDevice(id: AudioDeviceID(rawValue: 4), name: "Display Audio", supportedKinds: [.output])

    static let standard = AudioDeviceSnapshot(
        devices: [microphone, speakers, usbMicrophone, display],
        defaultInputID: microphone.id,
        defaultOutputID: speakers.id
    )

    var onChange: (@Sendable () -> Void)?
    var snapshotValue: AudioDeviceSnapshot
    var snapshotError: Error?
    var setError: Error?
    private(set) var setOperations: [SetOperation] = []

    init(snapshot: AudioDeviceSnapshot) {
        snapshotValue = snapshot
    }

    func snapshot() throws -> AudioDeviceSnapshot {
        if let snapshotError { throw snapshotError }
        return snapshotValue
    }

    func setDefaultDevice(id: AudioDeviceID, for kind: AudioDeviceKind) throws {
        if let setError { throw setError }
        guard let device = snapshotValue.devices.first(where: { $0.id == id }) else {
            throw AudioDeviceError.unavailable(kind)
        }
        guard device.supports(kind) else { throw AudioDeviceError.unsupported(kind) }
        setOperations.append(SetOperation(id: id, kind: kind))
        snapshotValue = AudioDeviceSnapshot(
            devices: snapshotValue.devices,
            defaultInputID: kind == .input ? id : snapshotValue.defaultInputID,
            defaultOutputID: kind == .output ? id : snapshotValue.defaultOutputID
        )
    }

    func sendChange() {
        onChange?()
    }
}

private enum FakeError: LocalizedError {
    case operationFailed

    var errorDescription: String? { "The fake CoreAudio operation failed." }
}

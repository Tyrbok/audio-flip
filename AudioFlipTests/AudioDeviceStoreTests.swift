import struct CoreAudio.AudioBuffer
import struct CoreAudio.AudioBufferList
import XCTest
@testable import AudioFlip

@MainActor
final class AudioDeviceStoreTests: XCTestCase {
    func testZeroBufferAudioConfigurationIsTreatedAsUnsupportedDirection() throws {
        let storage = UnsafeMutableRawPointer.allocate(
            byteCount: MemoryLayout<UInt32>.size,
            alignment: MemoryLayout<AudioBufferList>.alignment
        )
        defer { storage.deallocate() }
        storage.storeBytes(of: UInt32(0), as: UInt32.self)

        XCTAssertFalse(try AudioBufferListInspector.hasChannels(
            in: storage,
            byteCount: UInt32(MemoryLayout<UInt32>.size)
        ))
    }

    func testAudioConfigurationDetectsChannelsAndRejectsTruncatedData() throws {
        let buffersOffset = MemoryLayout<AudioBufferList>.offset(of: \.mBuffers)!
        let byteCount = buffersOffset + MemoryLayout<AudioBuffer>.stride
        let storage = UnsafeMutableRawPointer.allocate(
            byteCount: byteCount,
            alignment: MemoryLayout<AudioBufferList>.alignment
        )
        defer { storage.deallocate() }
        storage.initializeMemory(as: UInt8.self, repeating: 0, count: byteCount)
        storage.storeBytes(of: UInt32(1), toByteOffset: 0, as: UInt32.self)
        storage.storeBytes(
            of: AudioBuffer(mNumberChannels: 2, mDataByteSize: 0, mData: nil),
            toByteOffset: buffersOffset,
            as: AudioBuffer.self
        )

        XCTAssertTrue(try AudioBufferListInspector.hasChannels(in: storage, byteCount: UInt32(byteCount)))
        XCTAssertThrowsError(try AudioBufferListInspector.hasChannels(
            in: storage,
            byteCount: UInt32(buffersOffset)
        ))
    }

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

    func testSettingInputAndOutputVolumeChangesTheCurrentDevices() {
        let manager = FakeAudioDeviceManager(snapshot: FakeAudioDeviceManager.standard)
        let store = AudioDeviceStore(manager: manager)

        store.setVolume(0.4, for: .input)
        store.setVolume(0.8, for: .output)

        XCTAssertEqual(store.inputVolume, AudioDeviceVolume(value: 0.4, isSettable: true))
        XCTAssertEqual(store.outputVolume, AudioDeviceVolume(value: 0.8, isSettable: true))
        XCTAssertEqual(manager.volumeOperations, [
            .init(value: 0.4, id: FakeAudioDeviceManager.microphone.id, kind: .input),
            .init(value: 0.8, id: FakeAudioDeviceManager.speakers.id, kind: .output)
        ])
        XCTAssertNil(store.errorMessage)
    }

    func testVolumeControlIsIgnoredWhenTheDeviceDoesNotExposeOne() {
        let snapshot = AudioDeviceSnapshot(
            devices: FakeAudioDeviceManager.standard.devices,
            defaultInputID: FakeAudioDeviceManager.standard.defaultInputID,
            defaultOutputID: FakeAudioDeviceManager.standard.defaultOutputID,
            outputVolume: FakeAudioDeviceManager.standard.outputVolume
        )
        let manager = FakeAudioDeviceManager(snapshot: snapshot)
        let store = AudioDeviceStore(manager: manager)

        store.setVolume(0.3, for: .input)

        XCTAssertTrue(manager.volumeOperations.isEmpty)
        XCTAssertNil(store.errorMessage)
    }

    func testExternalVolumeChangeUpdatesTheSelectedDeviceVolume() async {
        let manager = FakeAudioDeviceManager(snapshot: FakeAudioDeviceManager.standard)
        let store = AudioDeviceStore(manager: manager)
        let volume = AudioDeviceVolume(value: 0.23, isSettable: true)

        manager.onVolumeChange?(FakeAudioDeviceManager.speakers.id, .output, volume)
        await Task.yield()

        XCTAssertEqual(store.outputVolume, volume)
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

    struct VolumeOperation: Equatable {
        let value: Double
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
        defaultOutputID: speakers.id,
        inputVolume: AudioDeviceVolume(value: 0.65, isSettable: true),
        outputVolume: AudioDeviceVolume(value: 0.55, isSettable: true)
    )

    var onChange: (@Sendable () -> Void)?
    var onVolumeChange: (@Sendable (AudioDeviceID, AudioDeviceKind, AudioDeviceVolume) -> Void)?
    var snapshotValue: AudioDeviceSnapshot
    var snapshotError: Error?
    var setError: Error?
    private(set) var setOperations: [SetOperation] = []
    private(set) var volumeOperations: [VolumeOperation] = []

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
            defaultOutputID: kind == .output ? id : snapshotValue.defaultOutputID,
            inputVolume: snapshotValue.inputVolume,
            outputVolume: snapshotValue.outputVolume
        )
    }

    func setVolume(_ value: Double, for id: AudioDeviceID, kind: AudioDeviceKind) throws -> AudioDeviceVolume {
        if let setError { throw setError }
        guard let device = snapshotValue.devices.first(where: { $0.id == id }) else {
            throw AudioDeviceError.unavailable(kind)
        }
        guard device.supports(kind) else { throw AudioDeviceError.unsupported(kind) }
        guard snapshotValueVolume(for: kind)?.isSettable == true else {
            throw FakeError.operationFailed
        }

        volumeOperations.append(VolumeOperation(value: value, id: id, kind: kind))
        let newVolume = AudioDeviceVolume(value: value, isSettable: true)
        snapshotValue = AudioDeviceSnapshot(
            devices: snapshotValue.devices,
            defaultInputID: snapshotValue.defaultInputID,
            defaultOutputID: snapshotValue.defaultOutputID,
            inputVolume: kind == .input ? newVolume : snapshotValue.inputVolume,
            outputVolume: kind == .output ? newVolume : snapshotValue.outputVolume
        )
        return newVolume
    }

    private func snapshotValueVolume(for kind: AudioDeviceKind) -> AudioDeviceVolume? {
        switch kind {
        case .input: snapshotValue.inputVolume
        case .output: snapshotValue.outputVolume
        }
    }

    func sendChange() {
        onChange?()
    }
}

private enum FakeError: LocalizedError {
    case operationFailed

    var errorDescription: String? { "The fake CoreAudio operation failed." }
}

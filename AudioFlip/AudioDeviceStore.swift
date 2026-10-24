import Combine
import Foundation
import os

@MainActor
final class AudioDeviceStore: ObservableObject {
    @Published private(set) var availableDevices: [AudioDevice] = []
    @Published private(set) var selectedInputID: AudioDeviceID?
    @Published private(set) var selectedOutputID: AudioDeviceID?
    @Published private(set) var inputVolume: AudioDeviceVolume?
    @Published private(set) var outputVolume: AudioDeviceVolume?
    @Published private(set) var errorMessage: String?

    private let manager: AudioDeviceManaging
    private let logger = Logger(subsystem: "com.example.AudioFlip", category: "AudioDeviceStore")

    init(manager: AudioDeviceManaging) {
        self.manager = manager
        manager.onChange = { [weak self] in
            Task { @MainActor in self?.refresh() }
        }
        manager.onVolumeChange = { [weak self] deviceID, kind, volume in
            Task { @MainActor in
                guard let self, self.selectedDeviceID(for: kind) == deviceID else { return }
                self.setVolume(volume, for: kind)
            }
        }
        refresh()
    }

    var outputs: [AudioDevice] { devices(for: .output) }
    var inputs: [AudioDevice] { devices(for: .input) }

    func devices(for kind: AudioDeviceKind) -> [AudioDevice] {
        availableDevices
            .filter { $0.supports(kind) }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    func isSelected(_ deviceID: AudioDeviceID, for kind: AudioDeviceKind) -> Bool {
        switch kind {
        case .input: selectedInputID == deviceID
        case .output: selectedOutputID == deviceID
        }
    }

    func volume(for kind: AudioDeviceKind) -> AudioDeviceVolume? {
        switch kind {
        case .input: inputVolume
        case .output: outputVolume
        }
    }

    func refresh() {
        refresh(clearExistingError: true)
    }

    func select(_ deviceID: AudioDeviceID, for kind: AudioDeviceKind) {
        guard let device = availableDevices.first(where: { $0.id == deviceID }) else {
            errorMessage = AudioDeviceError.unavailable(kind).localizedDescription
            return
        }
        guard device.supports(kind) else {
            errorMessage = AudioDeviceError.unsupported(kind).localizedDescription
            return
        }

        do {
            try manager.setDefaultDevice(id: deviceID, for: kind)
            refresh(clearExistingError: true)
        } catch {
            log(error, operation: "change the default \(kind.displayName.lowercased())")
            errorMessage = error.localizedDescription
            refresh(clearExistingError: false)
        }
    }

    func setVolume(_ value: Double, for kind: AudioDeviceKind) {
        guard let deviceID = selectedDeviceID(for: kind),
              volume(for: kind)?.isSettable == true else { return }

        let normalizedValue = min(max(value, 0), 1)
        do {
            let volume = try manager.setVolume(normalizedValue, for: deviceID, kind: kind)
            setVolume(volume, for: kind)
            errorMessage = nil
        } catch {
            log(error, operation: "change the default \(kind.displayName.lowercased()) volume")
            errorMessage = error.localizedDescription
        }
    }

    private func refresh(clearExistingError: Bool) {
        do {
            let snapshot = try manager.snapshot()
            availableDevices = snapshot.devices
            selectedInputID = snapshot.defaultInputID
            selectedOutputID = snapshot.defaultOutputID
            inputVolume = snapshot.inputVolume
            outputVolume = snapshot.outputVolume
            if clearExistingError { errorMessage = nil }
        } catch {
            log(error, operation: "refresh audio devices")
            errorMessage = error.localizedDescription
        }
    }

    private func log(_ error: Error, operation: String) {
        logger.error("Could not \(operation): \(error.localizedDescription, privacy: .public)")
    }

    private func selectedDeviceID(for kind: AudioDeviceKind) -> AudioDeviceID? {
        switch kind {
        case .input: selectedInputID
        case .output: selectedOutputID
        }
    }

    private func setVolume(_ volume: AudioDeviceVolume, for kind: AudioDeviceKind) {
        switch kind {
        case .input: inputVolume = volume
        case .output: outputVolume = volume
        }
    }
}

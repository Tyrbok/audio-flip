import SwiftUI

@main
struct AudioFlipApp: App {
    @StateObject private var store: AudioDeviceStore

    init() {
        let manager: AudioDeviceManaging
        do {
            manager = try CoreAudioDeviceManager()
        } catch {
            manager = FailedAudioDeviceManager(error: error)
        }
        _store = StateObject(wrappedValue: AudioDeviceStore(manager: manager))
    }

    var body: some Scene {
        MenuBarExtra("AudioFlip", systemImage: "waveform") {
            AudioFlipMenuView(store: store)
        }
        .menuBarExtraStyle(.window)
    }
}

private final class FailedAudioDeviceManager: AudioDeviceManaging {
    var onChange: (@Sendable () -> Void)?
    var onVolumeChange: (@Sendable (AudioDeviceID, AudioDeviceKind, AudioDeviceVolume) -> Void)?
    private let error: Error

    init(error: Error) {
        self.error = error
    }

    func snapshot() throws -> AudioDeviceSnapshot { throw error }

    func setDefaultDevice(id: AudioDeviceID, for kind: AudioDeviceKind) throws {
        throw error
    }

    func setVolume(_ value: Double, for id: AudioDeviceID, kind: AudioDeviceKind) throws -> AudioDeviceVolume {
        throw error
    }
}

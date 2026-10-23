import Foundation

struct AudioDeviceID: Hashable, Sendable {
    let rawValue: UInt32
}

enum AudioDeviceKind: String, CaseIterable, Hashable, Sendable {
    case output
    case input

    var displayName: String {
        switch self {
        case .output: "Output"
        case .input: "Input"
        }
    }
}

struct AudioDevice: Equatable, Identifiable, Sendable {
    let id: AudioDeviceID
    let name: String
    let supportedKinds: Set<AudioDeviceKind>

    func supports(_ kind: AudioDeviceKind) -> Bool {
        supportedKinds.contains(kind)
    }
}

struct AudioDeviceSnapshot: Equatable, Sendable {
    let devices: [AudioDevice]
    let defaultInputID: AudioDeviceID?
    let defaultOutputID: AudioDeviceID?

    func defaultID(for kind: AudioDeviceKind) -> AudioDeviceID? {
        switch kind {
        case .input: defaultInputID
        case .output: defaultOutputID
        }
    }
}

enum AudioDeviceError: LocalizedError, Equatable {
    case unavailable(AudioDeviceKind)
    case unsupported(AudioDeviceKind)

    var errorDescription: String? {
        switch self {
        case .unavailable(let kind): "That \(kind.displayName.lowercased()) device is no longer available."
        case .unsupported(let kind): "That device cannot be used for audio \(kind.displayName.lowercased())."
        }
    }
}

import Foundation

protocol AudioDeviceManaging: AnyObject {
    var onChange: (@Sendable () -> Void)? { get set }
    var onVolumeChange: (@Sendable (AudioDeviceID, AudioDeviceKind, AudioDeviceVolume) -> Void)? { get set }

    func snapshot() throws -> AudioDeviceSnapshot
    func setDefaultDevice(id: AudioDeviceID, for kind: AudioDeviceKind) throws
    func setVolume(_ value: Double, for id: AudioDeviceID, kind: AudioDeviceKind) throws -> AudioDeviceVolume
}

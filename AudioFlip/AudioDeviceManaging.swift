import Foundation

protocol AudioDeviceManaging: AnyObject {
    var onChange: (@Sendable () -> Void)? { get set }

    func snapshot() throws -> AudioDeviceSnapshot
    func setDefaultDevice(id: AudioDeviceID, for kind: AudioDeviceKind) throws
}

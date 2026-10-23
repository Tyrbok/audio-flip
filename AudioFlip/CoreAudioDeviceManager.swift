import CoreAudio
import Foundation
import os

final class CoreAudioDeviceManager: AudioDeviceManaging, @unchecked Sendable {
    private struct ListenerRegistration {
        let address: AudioObjectPropertyAddress
        let block: AudioObjectPropertyListenerBlock
    }

    private let listenerQueue = DispatchQueue(label: "com.example.AudioFlip.core-audio-listeners")
    private let callbackLock = NSLock()
    private var changeHandler: (@Sendable () -> Void)?
    private var listeners: [ListenerRegistration] = []
    private let logger = Logger(subsystem: "com.example.AudioFlip", category: "CoreAudio")

    var onChange: (@Sendable () -> Void)? {
        get {
            callbackLock.lock()
            defer { callbackLock.unlock() }
            return changeHandler
        }
        set {
            callbackLock.lock()
            defer { callbackLock.unlock() }
            changeHandler = newValue
        }
    }

    init() throws {
        try installListeners()
    }

    deinit {
        for listener in listeners {
            var address = listener.address
            let status = AudioObjectRemovePropertyListenerBlock(
                AudioObjectID(kAudioObjectSystemObject),
                &address,
                listenerQueue,
                listener.block
            )
            if status != noErr {
                logger.error("Could not remove CoreAudio listener (OSStatus \(status)).")
            }
        }
    }

    func snapshot() throws -> AudioDeviceSnapshot {
        let deviceIDs = try readDeviceIDs()
        var devices: [AudioDevice] = []
        for id in deviceIDs {
            do {
                if let device = try readDevice(id: id) {
                    devices.append(device)
                }
            } catch {
                // A device can vanish after enumeration but before its properties are read.
                guard try !readDeviceIDs().contains(id) else { throw error }
            }
        }
        return AudioDeviceSnapshot(
            devices: devices,
            defaultInputID: try readDefaultDevice(for: .input),
            defaultOutputID: try readDefaultDevice(for: .output)
        )
    }

    func setDefaultDevice(id: AudioDeviceID, for kind: AudioDeviceKind) throws {
        let device: AudioDevice
        do {
            guard let currentDevice = try readDevice(id: id) else {
                throw AudioDeviceError.unavailable(kind)
            }
            device = currentDevice
        } catch let error as AudioDeviceError {
            throw error
        } catch {
            guard try readDeviceIDs().contains(id) else {
                throw AudioDeviceError.unavailable(kind)
            }
            throw error
        }
        guard device.supports(kind) else { throw AudioDeviceError.unsupported(kind) }

        var address = defaultDeviceAddress(for: kind)
        var isSettable: DarwinBoolean = false
        var status = AudioObjectIsPropertySettable(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            &isSettable
        )
        guard status == noErr else {
            throw CoreAudioDeviceManagerError.propertyAccess("check whether the default \(kind.displayName.lowercased()) can be changed", status)
        }
        guard isSettable.boolValue else {
            throw CoreAudioDeviceManagerError.notSettable(kind)
        }

        var rawID = AudioObjectID(id.rawValue)
        status = AudioObjectSetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            0,
            nil,
            UInt32(MemoryLayout<AudioObjectID>.size),
            &rawID
        )
        guard status == noErr else {
            throw CoreAudioDeviceManagerError.propertyAccess("change the default \(kind.displayName.lowercased())", status)
        }
    }

    private func installListeners() throws {
        let selectors: [AudioObjectPropertySelector] = [
            kAudioHardwarePropertyDevices,
            kAudioHardwarePropertyDefaultInputDevice,
            kAudioHardwarePropertyDefaultOutputDevice
        ]

        do {
            for selector in selectors {
                var address = AudioObjectPropertyAddress(
                    mSelector: selector,
                    mScope: kAudioObjectPropertyScopeGlobal,
                    mElement: kAudioObjectPropertyElementMain
                )
                let block: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
                    self?.notifyChange()
                }
                let status = AudioObjectAddPropertyListenerBlock(
                    AudioObjectID(kAudioObjectSystemObject),
                    &address,
                    listenerQueue,
                    block
                )
                guard status == noErr else {
                    throw CoreAudioDeviceManagerError.listenerRegistration(status)
                }
                listeners.append(ListenerRegistration(address: address, block: block))
            }
        } catch {
            removeListeners()
            throw error
        }
    }

    private func removeListeners() {
        for listener in listeners {
            var address = listener.address
            let status = AudioObjectRemovePropertyListenerBlock(
                AudioObjectID(kAudioObjectSystemObject),
                &address,
                listenerQueue,
                listener.block
            )
            if status != noErr {
                logger.error("Could not remove CoreAudio listener (OSStatus \(status)).")
            }
        }
        listeners.removeAll()
    }

    private func notifyChange() {
        callbackLock.lock()
        let handler = changeHandler
        callbackLock.unlock()
        handler?()
    }

    private func readDeviceIDs() throws -> [AudioDeviceID] {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var byteCount: UInt32 = 0
        let object = AudioObjectID(kAudioObjectSystemObject)
        var status = AudioObjectGetPropertyDataSize(object, &address, 0, nil, &byteCount)
        guard status == noErr else {
            throw CoreAudioDeviceManagerError.propertyAccess("enumerate audio devices", status)
        }
        guard byteCount % UInt32(MemoryLayout<AudioObjectID>.size) == 0 else {
            throw CoreAudioDeviceManagerError.invalidPropertyData("audio device list")
        }

        let count = Int(byteCount) / MemoryLayout<AudioObjectID>.size
        guard count > 0 else { return [] }
        var rawIDs = [AudioObjectID](repeating: kAudioObjectUnknown, count: count)
        status = rawIDs.withUnsafeMutableBufferPointer { buffer in
            guard let baseAddress = buffer.baseAddress else { return noErr }
            return AudioObjectGetPropertyData(object, &address, 0, nil, &byteCount, baseAddress)
        }
        guard status == noErr else {
            throw CoreAudioDeviceManagerError.propertyAccess("read the audio device list", status)
        }
        return rawIDs.map { AudioDeviceID(rawValue: $0) }
    }

    private func readDevice(id: AudioDeviceID) throws -> AudioDevice? {
        let rawID = AudioObjectID(id.rawValue)
        guard rawID != kAudioObjectUnknown else { return nil }

        let name = try readDeviceName(id: rawID)

        var supportedKinds = Set<AudioDeviceKind>()
        if try hasChannels(device: rawID, scope: kAudioDevicePropertyScopeOutput) {
            supportedKinds.insert(.output)
        }
        if try hasChannels(device: rawID, scope: kAudioDevicePropertyScopeInput) {
            supportedKinds.insert(.input)
        }
        guard !supportedKinds.isEmpty else { return nil }
        return AudioDevice(id: id, name: name, supportedKinds: supportedKinds)
    }

    private func hasChannels(device: AudioObjectID, scope: AudioObjectPropertyScope) throws -> Bool {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyStreamConfiguration,
            mScope: scope,
            mElement: kAudioObjectPropertyElementMain
        )
        var byteCount: UInt32 = 0
        var status = AudioObjectGetPropertyDataSize(device, &address, 0, nil, &byteCount)
        guard status == noErr else {
            throw CoreAudioDeviceManagerError.propertyAccess("inspect audio device channels", status)
        }
        guard byteCount >= UInt32(MemoryLayout<AudioBufferList>.size) else {
            throw CoreAudioDeviceManagerError.invalidPropertyData("audio channel configuration")
        }

        let storage = UnsafeMutableRawPointer.allocate(
            byteCount: Int(byteCount),
            alignment: MemoryLayout<AudioBufferList>.alignment
        )
        defer { storage.deallocate() }
        storage.initializeMemory(as: UInt8.self, repeating: 0, count: Int(byteCount))

        status = AudioObjectGetPropertyData(device, &address, 0, nil, &byteCount, storage)
        guard status == noErr else {
            throw CoreAudioDeviceManagerError.propertyAccess("read audio device channels", status)
        }
        let buffers = UnsafeMutableAudioBufferListPointer(storage.bindMemory(to: AudioBufferList.self, capacity: 1))
        return buffers.contains { $0.mNumberChannels > 0 }
    }

    private func readDefaultDevice(for kind: AudioDeviceKind) throws -> AudioDeviceID? {
        var address = defaultDeviceAddress(for: kind)
        var rawID = AudioObjectID(kAudioObjectUnknown)
        var byteCount = UInt32(MemoryLayout<AudioObjectID>.size)
        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            0,
            nil,
            &byteCount,
            &rawID
        )
        guard status == noErr else {
            throw CoreAudioDeviceManagerError.propertyAccess(
                "read the default \(kind.displayName.lowercased())",
                status
            )
        }
        guard rawID != kAudioObjectUnknown else { return nil }
        return AudioDeviceID(rawValue: rawID)
    }

    private func readDeviceName(id: AudioObjectID) throws -> String {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioObjectPropertyName,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var name: Unmanaged<CFString>?
        var byteCount = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        let status = AudioObjectGetPropertyData(id, &address, 0, nil, &byteCount, &name)
        guard status == noErr else {
            throw CoreAudioDeviceManagerError.propertyAccess("read an audio device name", status)
        }
        guard let name else {
            throw CoreAudioDeviceManagerError.invalidPropertyData("audio device name")
        }
        return name.takeRetainedValue() as String
    }

    private func defaultDeviceAddress(for kind: AudioDeviceKind) -> AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(
            mSelector: kind == .input ? kAudioHardwarePropertyDefaultInputDevice : kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
    }

}

private enum CoreAudioDeviceManagerError: LocalizedError {
    case propertyAccess(String, OSStatus)
    case invalidPropertyData(String)
    case listenerRegistration(OSStatus)
    case notSettable(AudioDeviceKind)

    var errorDescription: String? {
        switch self {
        case .propertyAccess(let operation, let status):
            "Could not \(operation) (CoreAudio error \(status))."
        case .invalidPropertyData(let property):
            "CoreAudio returned invalid data for the \(property)."
        case .listenerRegistration(let status):
            "Could not listen for audio device changes (CoreAudio error \(status))."
        case .notSettable(let kind):
            "macOS does not allow the default \(kind.displayName.lowercased()) to be changed."
        }
    }
}

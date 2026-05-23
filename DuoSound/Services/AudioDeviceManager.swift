import CoreAudio
import Foundation

enum AudioManagerError: LocalizedError {
    case deviceCreationFailed(OSStatus)
    case deviceDestructionFailed(OSStatus)
    case propertyWriteFailed(OSStatus)

    var errorDescription: String? {
        switch self {
        case .deviceCreationFailed(let s):  return "Failed to create multi-output device (OSStatus \(s))"
        case .deviceDestructionFailed(let s): return "Failed to destroy multi-output device (OSStatus \(s))"
        case .propertyWriteFailed(let s):   return "Failed to set default device (OSStatus \(s))"
        }
    }
}

final class AudioDeviceManager {

    static let shared = AudioDeviceManager()
    private init() {}

    // MARK: - Enumeration

    func allOutputDevices() -> [AudioDevice] {
        var addr = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(systemObject, &addr, 0, nil, &size) == noErr else { return [] }
        let count = Int(size) / MemoryLayout<AudioDeviceID>.size
        var ids = [AudioDeviceID](repeating: 0, count: count)
        guard AudioObjectGetPropertyData(systemObject, &addr, 0, nil, &size, &ids) == noErr else { return [] }
        return ids.compactMap { buildDevice($0) }
    }

    private func buildDevice(_ id: AudioDeviceID) -> AudioDevice? {
        // Require output streams
        var outAddr = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyStreams,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        var streamsSize: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(id, &outAddr, 0, nil, &streamsSize) == noErr,
              streamsSize > 0 else { return nil }

        guard let name = stringProperty(id, kAudioDevicePropertyDeviceNameCFString),
              let uid  = stringProperty(id, kAudioDevicePropertyDeviceUID) else { return nil }

        let transport = transportType(id)
        guard transport != .aggregate else { return nil } // Skip our own aggregate

        return AudioDevice(
            id: id,
            uid: uid,
            name: name,
            transportType: transport,
            nominalSampleRate: sampleRate(id),
            batteryLevel: nil
        )
    }

    // MARK: - Default device

    func defaultOutputDeviceID() -> AudioDeviceID? {
        var addr = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var id = AudioDeviceID(kAudioDeviceUnknown)
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        guard AudioObjectGetPropertyData(systemObject, &addr, 0, nil, &size, &id) == noErr,
              id != kAudioDeviceUnknown else { return nil }
        return id
    }

    func setDefaultOutputDevice(_ id: AudioDeviceID) throws {
        var addr = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var deviceID = id
        let s = AudioObjectSetPropertyData(systemObject, &addr, 0, nil,
                                           UInt32(MemoryLayout<AudioDeviceID>.size), &deviceID)
        guard s == noErr else { throw AudioManagerError.propertyWriteFailed(s) }
    }

    func uidForDevice(_ id: AudioDeviceID) -> String? {
        stringProperty(id, kAudioDevicePropertyDeviceUID)
    }

    func deviceIDForUID(_ uid: String) -> AudioDeviceID? {
        var addr = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(systemObject, &addr, 0, nil, &size) == noErr else { return nil }
        let count = Int(size) / MemoryLayout<AudioDeviceID>.size
        var ids = [AudioDeviceID](repeating: 0, count: count)
        guard AudioObjectGetPropertyData(systemObject, &addr, 0, nil, &size, &ids) == noErr else { return nil }
        return ids.first { stringProperty($0, kAudioDevicePropertyDeviceUID) == uid }
    }

    // MARK: - Multi-Output Device

    func createMultiOutputDevice(deviceUIDs: [String], masterUID: String) throws -> AudioDeviceID {
        let subDevices = deviceUIDs.map { [kAudioSubDeviceUIDKey as String: $0] }
        let desc: [String: Any] = [
            kAudioAggregateDeviceNameKey as String: "DuoSound Multi-Output",
            kAudioAggregateDeviceUIDKey as String: "com.duosound.multioutput.\(UUID().uuidString)",
            kAudioAggregateDeviceSubDeviceListKey as String: subDevices,
            kAudioAggregateDeviceIsStackedKey as String: NSNumber(value: 1),
            kAudioAggregateDeviceMasterSubDeviceKey as String: masterUID,
        ]
        var aggID = AudioDeviceID(kAudioObjectUnknown)
        let s = AudioHardwareCreateAggregateDevice(desc as CFDictionary, &aggID)
        guard s == noErr else { throw AudioManagerError.deviceCreationFailed(s) }

        // Minimize I/O buffer size to reduce latency.
        // We clamp to the device's reported minimum so we never go below what's stable.
        minimizeBufferSize(aggID)

        return aggID
    }

    // Reads kAudioDevicePropertyBufferFrameSizeRange and sets the device to its
    // minimum stable value. Smaller buffers = less queued audio = lower latency.
    private func minimizeBufferSize(_ id: AudioDeviceID) {
        var rangeAddr = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyBufferFrameSizeRange,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        var range = AudioValueRange(mMinimum: 0, mMaximum: 0)
        var rangeSize = UInt32(MemoryLayout<AudioValueRange>.size)
        guard AudioObjectGetPropertyData(id, &rangeAddr, 0, nil, &rangeSize, &range) == noErr,
              range.mMinimum > 0 else { return }

        // Use the hardware minimum, floored at 256 frames to avoid glitches on
        // Bluetooth devices whose true minimum is unreliably small.
        let target = UInt32(max(range.mMinimum, 256))
        var bufAddr = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyBufferFrameSize,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        var frames = target
        AudioObjectSetPropertyData(id, &bufAddr, 0, nil,
                                   UInt32(MemoryLayout<UInt32>.size), &frames)
    }

    // Returns the total reported latency (device + stream + safety offset) in ms.
    func reportedLatencyMs(_ id: AudioDeviceID) -> Double {
        func uint32Prop(_ sel: AudioObjectPropertySelector, _ scope: AudioObjectPropertyScope) -> UInt32 {
            var addr = AudioObjectPropertyAddress(mSelector: sel, mScope: scope,
                                                  mElement: kAudioObjectPropertyElementMain)
            var val: UInt32 = 0
            var sz = UInt32(MemoryLayout<UInt32>.size)
            AudioObjectGetPropertyData(id, &addr, 0, nil, &sz, &val)
            return val
        }
        let scope = kAudioDevicePropertyScopeOutput
        let deviceLatency = uint32Prop(kAudioDevicePropertyLatency, scope)
        let safetyOffset  = uint32Prop(kAudioDevicePropertySafetyOffset, scope)
        let bufferFrames  = uint32Prop(kAudioDevicePropertyBufferFrameSize, scope)
        let sampleRate    = sampleRate(id)
        guard sampleRate > 0 else { return 0 }
        let totalFrames = Double(deviceLatency + safetyOffset + bufferFrames)
        return (totalFrames / sampleRate) * 1000
    }

    // MARK: - Per-device volume

    func getVolume(_ id: AudioDeviceID) -> Float {
        var addr = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyVolumeScalar,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        var vol: Float32 = 1.0
        var size = UInt32(MemoryLayout<Float32>.size)
        if AudioObjectGetPropertyData(id, &addr, 0, nil, &size, &vol) == noErr { return vol }
        // Fallback: try channel 1 (left)
        addr.mElement = 1
        if AudioObjectGetPropertyData(id, &addr, 0, nil, &size, &vol) == noErr { return vol }
        return 1.0
    }

    func setVolume(_ id: AudioDeviceID, volume: Float) {
        var vol = Float32(max(0, min(1, volume)))
        let size = UInt32(MemoryLayout<Float32>.size)
        // Try master channel first, then per-channel
        for element: UInt32 in [kAudioObjectPropertyElementMain, 1, 2] {
            var addr = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyVolumeScalar,
                mScope: kAudioDevicePropertyScopeOutput,
                mElement: element
            )
            AudioObjectSetPropertyData(id, &addr, 0, nil, size, &vol)
        }
    }

    func supportsVolume(_ id: AudioDeviceID) -> Bool {
        var addr = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyVolumeScalar,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        var settable: DarwinBoolean = false
        AudioObjectIsPropertySettable(id, &addr, &settable)
        if settable.boolValue { return true }
        // Check channel 1
        addr.mElement = 1
        AudioObjectIsPropertySettable(id, &addr, &settable)
        return settable.boolValue
    }

    func destroyMultiOutputDevice(_ id: AudioDeviceID) throws {
        let s = AudioHardwareDestroyAggregateDevice(id)
        guard s == noErr else { throw AudioManagerError.deviceDestructionFailed(s) }
    }

    // MARK: - Notifications

    typealias ListenerBlock = AudioObjectPropertyListenerBlock

    func addDeviceListListener(_ block: @escaping () -> Void) -> ListenerBlock {
        var addr = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        let listener: ListenerBlock = { _, _ in DispatchQueue.main.async { block() } }
        AudioObjectAddPropertyListenerBlock(systemObject, &addr, .main, listener)
        return listener
    }

    func removeDeviceListListener(_ listener: @escaping ListenerBlock) {
        var addr = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        AudioObjectRemovePropertyListenerBlock(systemObject, &addr, .main, listener)
    }

    // MARK: - Helpers

    private var systemObject: AudioObjectID { AudioObjectID(kAudioObjectSystemObject) }

    private func stringProperty(_ id: AudioObjectID, _ selector: AudioObjectPropertySelector) -> String? {
        var addr = AudioObjectPropertyAddress(
            mSelector: selector,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var unmanaged: Unmanaged<CFString>? = nil
        var size = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        guard AudioObjectGetPropertyData(id, &addr, 0, nil, &size, &unmanaged) == noErr,
              let cfStr = unmanaged?.takeRetainedValue() else { return nil }
        return cfStr as String
    }

    private func transportType(_ id: AudioDeviceID) -> AudioDevice.TransportType {
        var addr = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyTransportType,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var t: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        AudioObjectGetPropertyData(id, &addr, 0, nil, &size, &t)
        switch t {
        case kAudioDeviceTransportTypeBuiltIn:      return .builtIn
        case kAudioDeviceTransportTypeBluetooth:    return .bluetooth
        case kAudioDeviceTransportTypeBluetoothLE:  return .bluetoothLE
        case kAudioDeviceTransportTypeUSB:          return .usb
        case kAudioDeviceTransportTypeThunderbolt:  return .thunderbolt
        case kAudioDeviceTransportTypePCI:          return .pci
        case kAudioDeviceTransportTypeFireWire:     return .firewire
        case kAudioDeviceTransportTypeHDMI:         return .hdmi
        case kAudioDeviceTransportTypeDisplayPort:  return .displayPort
        case kAudioDeviceTransportTypeAirPlay:      return .airPlay
        case kAudioDeviceTransportTypeVirtual:      return .virtual
        case kAudioDeviceTransportTypeAggregate:    return .aggregate
        default:                                    return .unknown
        }
    }

    private func sampleRate(_ id: AudioDeviceID) -> Double {
        var addr = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyNominalSampleRate,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var rate: Float64 = 48000
        var size = UInt32(MemoryLayout<Float64>.size)
        AudioObjectGetPropertyData(id, &addr, 0, nil, &size, &rate)
        return rate
    }
}

import CoreAudio
import Foundation

struct AudioDevice: Identifiable, Hashable, Equatable {
    let id: AudioDeviceID
    let uid: String
    let name: String
    let transportType: TransportType
    let nominalSampleRate: Double
    let batteryLevel: Float?

    var group: Group {
        switch transportType {
        case .builtIn:                             return .builtIn
        case .bluetooth, .bluetoothLE, .airPlay:   return .wireless
        default:                                   return .wired
        }
    }

    var transportLabel: String {
        switch transportType {
        case .builtIn:      return "Built-in"
        case .bluetooth:    return "Bluetooth"
        case .bluetoothLE:  return "Bluetooth LE"
        case .airPlay:      return "AirPlay 2"
        case .usb:          return "USB"
        case .thunderbolt:  return "Thunderbolt"
        case .pci:          return "PCI"
        case .firewire:     return "FireWire"
        case .hdmi:         return "HDMI"
        case .displayPort:  return "DisplayPort"
        case .virtual:      return "Virtual"
        case .aggregate:    return "Aggregate"
        case .unknown:      return "Unknown"
        }
    }

    var systemImageName: String {
        switch transportType {
        case .builtIn:              return "laptopcomputer"
        case .bluetooth, .bluetoothLE: return "headphones"
        case .airPlay:              return "airplayaudio"
        case .usb:                  return "hifispeaker"
        case .thunderbolt, .displayPort, .hdmi: return "display"
        default:                    return "speaker.wave.2"
        }
    }

    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (lhs: AudioDevice, rhs: AudioDevice) -> Bool { lhs.id == rhs.id }

    enum TransportType {
        case builtIn, bluetooth, bluetoothLE, usb, thunderbolt, pci, firewire
        case hdmi, displayPort, airPlay, virtual, aggregate, unknown
    }

    enum Group: String, CaseIterable {
        case builtIn = "Built-In"
        case wireless = "Wireless"
        case wired = "Wired"
    }
}

import Foundation
import CoreAudio
import Combine
import UserNotifications

struct AggregateState {
    let deviceUIDs: [String]
    let primaryUID: String
    let sampleRate: Double
    let originalDefaultUID: String
    var multiOutputDeviceID: AudioDeviceID
}

struct DisconnectEvent {
    let deviceUID: String
    let deviceName: String
}

@MainActor
final class AppState: ObservableObject {

    // MARK: - Published state

    @Published var devices: [AudioDevice] = []
    @Published var selectedUIDs: Set<String> = []
    @Published var aggregate: AggregateState? = nil
    @Published var defaultDeviceUID: String? = nil
    @Published var busy = false
    @Published var disconnectEvent: DisconnectEvent? = nil
    @Published var errorMessage: String? = nil
    @Published var hasShownWelcome: Bool
    @Published var deviceVolumes: [String: Float] = [:]   // uid → 0…1

    // MARK: - Private

    private let mgr = AudioDeviceManager.shared
    private var deviceListener: AudioDeviceManager.ListenerBlock?
    private static let selectedUIDsKey = "selectedUIDs"
    private static let welcomeShownKey = "welcomeShown"
    private static let deviceVolumesKey = "deviceVolumes"

    init() {
        hasShownWelcome = UserDefaults.standard.bool(forKey: Self.welcomeShownKey)
        let saved = UserDefaults.standard.stringArray(forKey: Self.selectedUIDsKey) ?? []
        selectedUIDs = Set(saved)
        if let vols = UserDefaults.standard.dictionary(forKey: Self.deviceVolumesKey) as? [String: Float] {
            deviceVolumes = vols
        }
        refresh()
        startListening()
        requestNotificationPermission()
    }

    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    deinit {
        if let l = deviceListener {
            AudioDeviceManager.shared.removeDeviceListListener(l)
        }
    }

    // MARK: - Device list

    func refresh() {
        let fresh = mgr.allOutputDevices()
        devices = fresh

        // Sync selectedUIDs — remove UIDs no longer present
        let availableUIDs = Set(fresh.map(\.uid))
        selectedUIDs = selectedUIDs.intersection(availableUIDs)

        // Update current default
        if let defID = mgr.defaultOutputDeviceID() {
            defaultDeviceUID = mgr.uidForDevice(defID)
        }

        // Check if any device in an active aggregate disconnected
        if let agg = aggregate {
            let disconnected = agg.deviceUIDs.first { uid in
                !availableUIDs.contains(uid) && uid != agg.multiOutputDeviceID.description
            }
            if let uid = disconnected, disconnectEvent == nil {
                let name = devices.first(where: { $0.uid == uid })?.name
                    ?? fresh.first(where: { $0.uid == uid })?.name
                    ?? uid
                disconnectEvent = DisconnectEvent(deviceUID: uid, deviceName: name)
                sendDisconnectNotification(deviceName: name)
            }
        }
    }

    private func startListening() {
        deviceListener = mgr.addDeviceListListener { [weak self] in
            self?.refresh()
        }
    }

    // MARK: - Selection

    func toggle(uid: String) {
        guard aggregate == nil else { return }
        if selectedUIDs.contains(uid) {
            selectedUIDs.remove(uid)
        } else {
            selectedUIDs.insert(uid)
        }
        persistSelection()
    }

    private func persistSelection() {
        UserDefaults.standard.set(Array(selectedUIDs), forKey: Self.selectedUIDsKey)
    }

    // MARK: - Fuse / Reset

    var canFuse: Bool {
        aggregate == nil && connectedSelected.count >= 2
    }

    var connectedSelected: [AudioDevice] {
        devices.filter { selectedUIDs.contains($0.uid) }
    }

    func fuse() async {
        guard canFuse else { return }
        busy = true
        defer { busy = false }
        errorMessage = nil

        let selected = connectedSelected
        // Primary = wired first, then highest sample rate
        let primary = selected.sorted {
            if ($0.group == .wired) != ($1.group == .wired) { return $0.group == .wired }
            return $0.nominalSampleRate > $1.nominalSampleRate
        }.first!

        let uids = selected.map(\.uid)
        let originalDefaultUID = defaultDeviceUID ?? ""

        do {
            let aggID = try mgr.createMultiOutputDevice(deviceUIDs: uids, masterUID: primary.uid)
            // Small delay to let CoreAudio register the new device
            try await Task.sleep(for: .milliseconds(600))
            try mgr.setDefaultOutputDevice(aggID)
            aggregate = AggregateState(
                deviceUIDs: uids,
                primaryUID: primary.uid,
                sampleRate: primary.nominalSampleRate,
                originalDefaultUID: originalDefaultUID,
                multiOutputDeviceID: aggID
            )
            defaultDeviceUID = mgr.uidForDevice(aggID)
            loadVolumesIntoDevices()
            NotificationCenter.default.post(name: .duoSoundStateChanged, object: nil)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func reset() async {
        guard let agg = aggregate else { return }
        busy = true
        defer { busy = false }
        errorMessage = nil

        do {
            // Restore original default first
            if let origID = mgr.deviceIDForUID(agg.originalDefaultUID) {
                try mgr.setDefaultOutputDevice(origID)
            }
            try await Task.sleep(for: .milliseconds(200))
            try mgr.destroyMultiOutputDevice(agg.multiOutputDeviceID)
        } catch {
            errorMessage = error.localizedDescription
        }

        aggregate = nil
        disconnectEvent = nil
        selectedUIDs = []
        persistSelection()
        refresh()
        NotificationCenter.default.post(name: .duoSoundStateChanged, object: nil)
    }

    func rebuildWithoutDisconnected() async {
        guard let agg = aggregate, let event = disconnectEvent else { return }
        let remaining = agg.deviceUIDs.filter { $0 != event.deviceUID }
        guard remaining.count >= 2 else {
            await reset()
            return
        }

        busy = true
        defer { busy = false }
        errorMessage = nil

        let remainingDevices = devices.filter { remaining.contains($0.uid) }
        let primary = remainingDevices.sorted {
            if ($0.group == .wired) != ($1.group == .wired) { return $0.group == .wired }
            return $0.nominalSampleRate > $1.nominalSampleRate
        }.first ?? remainingDevices[0]

        do {
            try mgr.destroyMultiOutputDevice(agg.multiOutputDeviceID)
            try await Task.sleep(for: .milliseconds(300))
            let newAggID = try mgr.createMultiOutputDevice(deviceUIDs: remaining, masterUID: primary.uid)
            try await Task.sleep(for: .milliseconds(600))
            try mgr.setDefaultOutputDevice(newAggID)
            aggregate = AggregateState(
                deviceUIDs: remaining,
                primaryUID: primary.uid,
                sampleRate: primary.nominalSampleRate,
                originalDefaultUID: agg.originalDefaultUID,
                multiOutputDeviceID: newAggID
            )
            disconnectEvent = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func dismissDisconnectEvent() {
        disconnectEvent = nil
    }

    // MARK: - Volume

    func setVolume(uid: String, volume: Float) {
        deviceVolumes[uid] = volume
        UserDefaults.standard.set(deviceVolumes, forKey: Self.deviceVolumesKey)
        if let device = devices.first(where: { $0.uid == uid }) {
            mgr.setVolume(device.id, volume: volume)
        }
    }

    func loadVolumesIntoDevices() {
        for (uid, vol) in deviceVolumes {
            if let device = devices.first(where: { $0.uid == uid }) {
                mgr.setVolume(device.id, volume: vol)
            }
        }
    }

    // MARK: - Welcome

    private func sendDisconnectNotification(deviceName: String) {
        let content = UNMutableNotificationContent()
        content.title = "DuoSound — Device Disconnected"
        content.body = "\"\(deviceName)\" left the mix. Open DuoSound to rebuild or reset."
        content.sound = .default
        let req = UNNotificationRequest(identifier: "disconnect-\(deviceName)",
                                        content: content, trigger: nil)
        UNUserNotificationCenter.current().add(req)
    }

    func acknowledgeWelcome() {
        hasShownWelcome = true
        UserDefaults.standard.set(true, forKey: Self.welcomeShownKey)
    }

    // MARK: - App lifecycle

    func handleTermination() {
        // Best-effort reset on quit — don't await since we're terminating
        if let agg = aggregate {
            if let origID = mgr.deviceIDForUID(agg.originalDefaultUID) {
                try? mgr.setDefaultOutputDevice(origID)
            }
            try? mgr.destroyMultiOutputDevice(agg.multiOutputDeviceID)
        }
    }
}

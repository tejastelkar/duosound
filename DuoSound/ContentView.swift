import SwiftUI
import AppKit

struct ContentView: View {
    @EnvironmentObject var state: AppState
    @State private var scrollContentHeight: CGFloat = 0

    var body: some View {
        VStack(spacing: 0) {
            if !state.hasShownWelcome {
                PermissionGateView { state.acknowledgeWelcome() }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                header
                Divider().opacity(0.5)
                mainContent
            }
        }
        .frame(width: 320)
        .background(VisualEffectView().ignoresSafeArea())
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .readSize { size in
            NotificationCenter.default.post(name: .popoverSizeChanged, object: size)
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "speaker.wave.2")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.primary)
            VStack(alignment: .leading, spacing: 1) {
                Text("DuoSound")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.primary)
                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                state.refresh()
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("Rescan audio devices")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color.clear)
    }

    private var subtitle: String {
        if state.aggregate != nil { return "Multi-Output active" }
        let n = state.devices.count
        return n == 0 ? "No outputs found" : "\(n) output\(n == 1 ? "" : "s") detected"
    }

    // MARK: - Main content

    @ViewBuilder
    private var mainContent: some View {
        VStack(spacing: 0) {
            if let agg = state.aggregate {
                AggregateCardView(aggregate: agg, devices: state.devices)
            }
            if let event = state.disconnectEvent {
                disconnectBanner(event: event)
            }
            if state.aggregate == nil && state.connectedSelected.count >= 2 {
                latencyHintBanner
            }
            if let err = state.errorMessage {
                BannerView(tone: .error, systemImage: "exclamationmark.triangle", title: "Error", body: err)
            }

            ScrollView(.vertical, showsIndicators: true) {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(AudioDevice.Group.allCases, id: \.self) { group in
                        let grouped = state.devices.filter { $0.group == group }
                        if !grouped.isEmpty {
                            deviceSection(group: group, devices: grouped)
                        }
                    }
                    HStack(spacing: 5) {
                        Image(systemName: "arrow.clockwise.circle")
                            .font(.system(size: 11))
                        Text("Listens for CoreAudio device changes automatically.")
                    }
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                }
                .background(
                    GeometryReader { geo in
                        Color.clear
                            .onAppear {
                                scrollContentHeight = geo.size.height
                            }
                            .onChange(of: geo.size.height) { newHeight in
                                scrollContentHeight = newHeight
                            }
                    }
                )
            }
            .frame(height: scrollContentHeight > 0 ? min(scrollContentHeight, 340) : nil)

            ActionBarView(
                canFuse: state.canFuse,
                hasAggregate: state.aggregate != nil,
                busy: state.busy,
                selectionCount: state.connectedSelected.count,
                onFuse: { Task { await state.fuse() } },
                onReset: { Task { await state.reset() } }
            )
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.75), value: state.devices)
        .animation(.spring(response: 0.35, dampingFraction: 0.75), value: state.aggregate != nil)
        .animation(.spring(response: 0.35, dampingFraction: 0.75), value: state.selectedUIDs)
    }

    // MARK: - Device section

    private func deviceSection(group: AudioDevice.Group, devices: [AudioDevice]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(group.rawValue.capitalized)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 14)
                .padding(.top, 10)
                .padding(.bottom, 4)
            ForEach(devices) { device in
                DeviceRowView(
                    device: device,
                    selected: state.selectedUIDs.contains(device.uid),
                    disabled: state.aggregate != nil,
                    isDefault: state.defaultDeviceUID == device.uid,
                    isInMix: state.aggregate?.deviceUIDs.contains(device.uid) == true,
                    volume: state.deviceVolumes[device.uid] ?? 1.0,
                    supportsVolume: AudioDeviceManager.shared.supportsVolume(device.id),
                    onToggle: { uid in
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                            state.toggle(uid: uid)
                        }
                    },
                    onVolumeChange: { vol in state.setVolume(uid: device.uid, volume: vol) }
                )
            }
        }
    }

    // MARK: - Banners

    private func disconnectBanner(event: DisconnectEvent) -> some View {
        let canRebuild = (state.aggregate?.deviceUIDs.filter { $0 != event.deviceUID }.count ?? 0) >= 2
        return BannerView(
            tone: .warn,
            systemImage: "exclamationmark.triangle",
            title: "\"\(event.deviceName)\" disconnected",
            body: "Rebuild with remaining devices or reset to original output.",
            actions: [
                BannerAction(
                    label: canRebuild ? "Rebuild" : "Reset",
                    isPrimary: true,
                    action: { Task { await state.rebuildWithoutDisconnected() } }
                ),
                BannerAction(label: "Dismiss", isPrimary: false, action: { state.dismissDisconnectEvent() })
            ]
        )
    }

    private var latencyHintBanner: some View {
        let hasWireless = state.connectedSelected.contains { $0.group == .wireless }
        let hasWired    = state.connectedSelected.contains { $0.group != .wireless }
        guard hasWireless && hasWired else { return AnyView(EmptyView()) }
        return AnyView(BannerView(
            tone: .info,
            title: "Sync note",
            body: "Bluetooth outputs typically lag wired by 30–250 ms."
        ))
    }
}

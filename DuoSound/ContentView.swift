import SwiftUI
import AppKit

struct ContentView: View {
    @EnvironmentObject var state: AppState
    @State private var scrollContentHeight: CGFloat = 0
    @State private var quitHovered = false
    @State private var supportHovered = false
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 0) {
            if !state.hasShownWelcome {
                PermissionGateView { state.acknowledgeWelcome() }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                header
                Divider().opacity(0.5)
                shareAudioToggleRow
                Divider().opacity(0.5)
                mainContent
            }
        }
        .frame(width: 320)
        .background(
            ZStack {
                VisualEffectView()
                if colorScheme == .light {
                    Color.white.opacity(0.90)
                }
            }
            .ignoresSafeArea()
        )
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

            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                Image(systemName: "power")
                    .font(.system(size: 12))
                    .foregroundStyle(quitHovered ? Color.red : Color.secondary)
                    .scaleEffect(quitHovered ? 1.15 : 1.0)
            }
            .buttonStyle(.plain)
            .help("Quit DuoSound")
            .onHover { hovering in
                withAnimation(.easeInOut(duration: 0.15)) { quitHovered = hovering }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color.clear)
    }

    // MARK: - Share Audio toggle

    private var shareAudioToggleRow: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Share Audio")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.primary)
                Text(toggleSubtitle)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .animation(.easeInOut(duration: 0.2), value: toggleSubtitle)
            }
            Spacer()
            Group {
                if state.busy {
                    ProgressView()
                        .scaleEffect(0.75)
                        .frame(width: 51, height: 31)
                } else {
                    Toggle("", isOn: shareAudioBinding)
                        .labelsHidden()
                        .toggleStyle(.switch)
                        .disabled(state.aggregate == nil && !state.canFuse)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    private var toggleSubtitle: String {
        if state.aggregate != nil { return "Audio mirrored on \(state.aggregate!.deviceUIDs.count) devices" }
        let n = state.connectedSelected.count
        if n == 0 { return "Select two or more devices below" }
        if n == 1 { return "Select one more device to share" }
        return "\(n) devices ready to share"
    }

    private var shareAudioBinding: Binding<Bool> {
        Binding(
            get: { state.aggregate != nil },
            set: { on in
                if on  { Task { await state.fuse()  } }
                else   { Task { await state.reset() } }
            }
        )
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
                    HStack {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.clockwise.circle")
                                .font(.system(size: 11))
                            Text("Listens for CoreAudio device changes automatically.")
                                .font(.system(size: 11))
                        }
                        .foregroundStyle(.secondary)

                        Spacer()

                        Button {
                            NSWorkspace.shared.open(URL(string: "https://ko-fi.com/tejastelkar")!)
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "cup.and.saucer.fill")
                                    .font(.system(size: 10))
                                Text("Support")
                                    .font(.system(size: 11, weight: .medium))
                            }
                            .foregroundStyle(supportHovered ? Color.accentColor : Color.secondary)
                            .scaleEffect(supportHovered ? 1.05 : 1.0)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(
                                RoundedRectangle(cornerRadius: 5, style: .continuous)
                                    .fill(supportHovered ? Color.accentColor.opacity(0.12) : Color.clear)
                            )
                        }
                        .buttonStyle(.plain)
                        .help("Support DuoSound on Ko-fi")
                        .onHover { hovering in
                            withAnimation(.easeInOut(duration: 0.15)) { supportHovered = hovering }
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
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

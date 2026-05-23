import SwiftUI

struct DeviceRowView: View {
    let device: AudioDevice
    let selected: Bool
    let disabled: Bool
    let isDefault: Bool
    let isInMix: Bool
    let volume: Float
    let supportsVolume: Bool
    let onToggle: (String) -> Void
    let onVolumeChange: ((Float) -> Void)?

    @State private var hovering = false
    @State private var localVolume: Float = 1.0

    init(device: AudioDevice, selected: Bool, disabled: Bool, isDefault: Bool,
         isInMix: Bool, volume: Float = 1.0, supportsVolume: Bool = false,
         onToggle: @escaping (String) -> Void, onVolumeChange: ((Float) -> Void)? = nil) {
        self.device = device; self.selected = selected; self.disabled = disabled
        self.isDefault = isDefault; self.isInMix = isInMix
        self.volume = volume; self.supportsVolume = supportsVolume
        self.onToggle = onToggle; self.onVolumeChange = onVolumeChange
        self._localVolume = State(initialValue: volume)
    }

    private var interactive: Bool { !disabled }

    var body: some View {
        HStack(spacing: 12) {
            iconCell
            info
            Spacer(minLength: 0)
            checkbox
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .frame(minHeight: 46)
        .background(hovering && interactive ? Color.secondary.opacity(0.1) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .contentShape(Rectangle())
        .onHover { hovering = interactive && $0 }
        .onTapGesture { if interactive { onToggle(device.uid) } }
        .opacity(1.0)
        .cursor(interactive ? .pointingHand : .arrow)
    }

    // MARK: - Subviews

    private var iconCell: some View {
        ZStack(alignment: .bottomTrailing) {
            Circle()
                .fill(iconBackground)
                .frame(width: 32, height: 32)
                .overlay(
                    Image(systemName: device.systemImageName)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(iconForeground)
                )
        }
    }

    private var iconBackground: Color {
        if selected || isInMix || isDefault { return .blue }
        return Color.secondary.opacity(0.15)
    }

    private var iconForeground: Color {
        if selected || isInMix || isDefault { return .white }
        return .primary
    }

    private var info: some View {
        VStack(alignment: .leading, spacing: 2) {
            // Name + pills
            HStack(spacing: 6) {
                Text(device.name)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                if isDefault && !isInMix {
                    PillView(label: "Default", color: .blue)
                }
                if isInMix {
                    PillView(label: "In Mix", color: .blue, textColor: .white, bg: .blue)
                }
            }
            // Meta row
            HStack(spacing: 4) {
                Text(device.transportLabel)
                if device.nominalSampleRate > 0 {
                    Text("·").opacity(0.4)
                    Text(formattedSampleRate)
                }
                if let bat = device.batteryLevel {
                    Text("·").opacity(0.4)
                    Text("\(Int(bat))%")
                        .foregroundStyle(bat < 20 ? Color.orange : .secondary)
                }
            }
            .font(.system(size: 11))
            .foregroundStyle(.secondary)

            // Volume slider — only visible when device is in the active mix
            if isInMix && supportsVolume {
                HStack(spacing: 6) {
                    Image(systemName: localVolume < 0.01 ? "speaker.slash" : "speaker.fill")
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                        .frame(width: 10)
                    Slider(value: $localVolume, in: 0...1) { editing in
                        if !editing { onVolumeChange?(localVolume) }
                    }
                    .tint(.blue)
                    .frame(height: 12)
                    Text("\(Int(localVolume * 100))%")
                        .font(.system(size: 10).monospacedDigit())
                        .foregroundStyle(.secondary)
                        .frame(width: 30, alignment: .trailing)
                }
                .padding(.top, 2)
            }
        }
        .onChange(of: volume) { localVolume = $0 }
    }

    private var checkbox: some View {
        ZStack {
            if selected {
                Image(systemName: "checkmark")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.blue)
            }
        }
        .frame(width: 20, height: 20)
        .opacity(interactive ? 1 : 0.45)
        .animation(.easeInOut(duration: 0.12), value: selected)
    }

    private var formattedSampleRate: String {
        let khz = device.nominalSampleRate / 1000
        return khz.truncatingRemainder(dividingBy: 1) == 0
            ? "\(Int(khz)) kHz"
            : "\(khz) kHz"
    }
}

private struct PillView: View {
    let label: String
    var color: Color = .blue
    var textColor: Color = .white
    var bg: Color? = nil

    var body: some View {
        Text(label.uppercased())
            .font(.system(size: 10, weight: .semibold))
            .tracking(0.3)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(bg ?? color)
            .foregroundStyle(textColor)
            .clipShape(RoundedRectangle(cornerRadius: 4))
    }
}

// MARK: - Cursor helper

private extension View {
    func cursor(_ cursor: NSCursor) -> some View {
        self.onHover { inside in
            if inside { cursor.push() } else { NSCursor.pop() }
        }
    }
}

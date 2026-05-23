import SwiftUI

struct AggregateCardView: View {
    let aggregate: AggregateState
    let devices: [AudioDevice]

    private var aggDevices: [AudioDevice] {
        aggregate.deviceUIDs.compactMap { uid in devices.first(where: { $0.uid == uid }) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header row
            HStack(spacing: 8) {
                AudioWaveIcon()
                Text("Multi-Output Active")
                    .font(.system(size: 11.5, weight: .bold))
                    .tracking(0.6)
                    .textCase(.uppercase)
                    .foregroundStyle(Color(red: 0.075, green: 0.467, blue: 0.165))
                Spacer()
                Text("\(aggDevices.count) devices · \(formattedRate) · ~\(latencyMs) ms")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.black.opacity(0.5))
            }

            // Device chips
            WrappingHStack(spacing: 6) {
                ForEach(aggDevices) { device in
                    DeviceChip(
                        device: device,
                        isPrimary: device.uid == aggregate.primaryUID
                    )
                }
            }

            // Audio meter
            AudioMeterView()
                .frame(height: 18)
                .clipShape(RoundedRectangle(cornerRadius: 4))
                .background(Color.black.opacity(0.06).clipShape(RoundedRectangle(cornerRadius: 4)))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 11)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.098, green: 0.639, blue: 0.165).opacity(0.08),
                            Color(red: 0.098, green: 0.639, blue: 0.165).opacity(0.04)
                        ],
                        startPoint: .top, endPoint: .bottom
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 11)
                        .strokeBorder(Color(red: 0.098, green: 0.639, blue: 0.165).opacity(0.22), lineWidth: 0.5)
                )
        )
        .padding(.horizontal, 14)
        .padding(.top, 12)
    }

    private var formattedRate: String {
        let khz = aggregate.sampleRate / 1000
        return khz.truncatingRemainder(dividingBy: 1) == 0
            ? "\(Int(khz)) kHz"
            : "\(khz) kHz"
    }

    private var latencyMs: String {
        let ms = AudioDeviceManager.shared.reportedLatencyMs(aggregate.multiOutputDeviceID)
        return ms > 0 ? String(format: "%.0f", ms) : "—"
    }
}

// MARK: - Device chip

private struct DeviceChip: View {
    let device: AudioDevice
    let isPrimary: Bool

    private var greenDark: Color { Color(red: 0.098, green: 0.639, blue: 0.165) }

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: device.systemImageName)
                .font(.system(size: 12, weight: .regular))
                .foregroundStyle(isPrimary ? Color.white : Color.black.opacity(0.7))
            Text(device.name)
                .font(.system(size: 11.5, weight: .medium))
                .lineLimit(1)
            if isPrimary {
                Text("CLOCK")
                    .font(.system(size: 9, weight: .bold))
                    .tracking(0.4)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(Color.white.opacity(0.22))
                    .clipShape(RoundedRectangle(cornerRadius: 3))
            }
        }
        .padding(.leading, 6)
        .padding(.trailing, 9)
        .padding(.vertical, 5)
        .background(isPrimary ? greenDark : Color.white)
        .foregroundStyle(isPrimary ? Color.white : Color.black.opacity(0.75))
        .clipShape(Capsule())
        .overlay(
            Capsule().strokeBorder(isPrimary ? Color.clear : Color.black.opacity(0.10), lineWidth: 0.5)
        )
    }
}

// MARK: - Audio wave icon

private struct AudioWaveIcon: View {
    var body: some View {
        HStack(spacing: 1.5) {
            ForEach([4, 7, 10, 7, 4], id: \.self) { h in
                Capsule()
                    .fill(Color(red: 0.098, green: 0.639, blue: 0.165))
                    .frame(width: 1.6, height: CGFloat(h))
            }
        }
        .frame(width: 14, height: 14)
    }
}

// MARK: - Audio meter

struct AudioMeterView: View {
    @State private var phase: Double = 0

    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { ctx, size in
                let t = timeline.date.timeIntervalSinceReferenceDate
                let barCount = 36
                let gap: CGFloat = 2
                let barW = (size.width - gap * CGFloat(barCount - 1)) / CGFloat(barCount)
                for i in 0..<barCount {
                    let fi = Double(i)
                    let speed = t * 12.0
                    let h = 4 + (sin(speed + fi * 0.8) * 0.5 + 0.5) *
                                (sin(speed * 0.6 + fi * 0.4) * 0.5 + 0.5) * (size.height - 4)
                    let x = CGFloat(i) * (barW + gap)
                    let rect = CGRect(x: x, y: size.height - CGFloat(h), width: barW, height: CGFloat(h))
                    ctx.fill(
                        Path(roundedRect: rect, cornerRadius: 1),
                        with: .linearGradient(
                            Gradient(colors: [
                                Color(red: 0.145, green: 0.769, blue: 0.243),
                                Color(red: 0.098, green: 0.639, blue: 0.165)
                            ]),
                            startPoint: CGPoint(x: 0, y: 0),
                            endPoint: CGPoint(x: 0, y: size.height)
                        )
                    )
                }
            }
        }
    }
}

// MARK: - Flow layout

private struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, rowH: CGFloat = 0
        for sub in subviews {
            let s = sub.sizeThatFits(.unspecified)
            if x + s.width > maxWidth, x > 0 {
                y += rowH + spacing; x = 0; rowH = 0
            }
            x += s.width + spacing
            rowH = max(rowH, s.height)
        }
        return CGSize(width: maxWidth, height: y + rowH)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, rowH: CGFloat = 0
        for sub in subviews {
            let s = sub.sizeThatFits(.unspecified)
            if x + s.width > bounds.maxX, x > bounds.minX {
                x = bounds.minX; y += rowH + spacing; rowH = 0
            }
            sub.place(at: CGPoint(x: x, y: y), proposal: .unspecified)
            x += s.width + spacing
            rowH = max(rowH, s.height)
        }
    }
}

private struct WrappingHStack<Content: View>: View {
    let spacing: CGFloat
    @ViewBuilder let content: Content

    var body: some View {
        FlowLayout(spacing: spacing) { content }
    }
}

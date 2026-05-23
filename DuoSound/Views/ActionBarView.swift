import SwiftUI

struct ActionBarView: View {
    let canFuse: Bool
    let hasAggregate: Bool
    let busy: Bool
    let selectionCount: Int
    let onFuse: () -> Void
    let onReset: () -> Void

    private var fuseDisabled: Bool { busy || !canFuse }
    private var resetDisabled: Bool { busy || !hasAggregate }

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            statusText
            Spacer()
            resetButton
            fuseButton
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Color.clear)
        .overlay(alignment: .top) {
            Divider().opacity(0.6)
        }
    }

    private var statusText: some View {
        Text(statusMessage)
            .font(.system(size: 11))
            .foregroundStyle(.secondary)
    }

    private var statusMessage: String {
        if hasAggregate { return "Audio is being mirrored on multiple devices." }
        if selectionCount == 0 { return "Select two or more devices to combine." }
        if selectionCount == 1 { return "Select at least one more device." }
        return "\(selectionCount) devices selected."
    }

    private var resetButton: some View {
        Button("Reset", action: onReset)
            .buttonStyle(SecondaryButtonStyle(disabled: resetDisabled))
            .disabled(resetDisabled)
    }

    private var fuseButton: some View {
        Button(action: onFuse) {
            if busy {
                HStack(spacing: 6) {
                    ProgressView().scaleEffect(0.6).frame(width: 12, height: 12)
                    Text("Creating…")
                }
            } else {
                HStack(spacing: 6) {
                    Image(systemName: "play.fill").font(.system(size: 10))
                    Text("Play on Both")
                }
            }
        }
        .buttonStyle(PrimaryButtonStyle(disabled: fuseDisabled))
        .disabled(fuseDisabled)
    }
}

// MARK: - Button styles

struct PrimaryButtonStyle: ButtonStyle {
    let disabled: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(disabled ? Color.secondary.opacity(0.5) : Color.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 7)
            .background(
                disabled
                    ? AnyShapeStyle(Color.secondary.opacity(0.1))
                    : AnyShapeStyle(Color.blue)
            )
            .clipShape(RoundedRectangle(cornerRadius: 7))
            .shadow(color: disabled ? .clear : Color.black.opacity(0.1), radius: 1, y: 1)
            .opacity(configuration.isPressed && !disabled ? 0.9 : 1)
            .animation(.easeInOut(duration: 0.12), value: configuration.isPressed)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    let disabled: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(disabled ? Color.secondary.opacity(0.5) : .primary)
            .padding(.horizontal, 16)
            .padding(.vertical, 7)
            .background(disabled ? Color.clear : Color.secondary.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 7))
            .overlay(
                RoundedRectangle(cornerRadius: 7)
                    .strokeBorder(
                        Color.secondary.opacity(0.15),
                        lineWidth: 0.5
                    )
            )
            .opacity(configuration.isPressed && !disabled ? 0.85 : 1)
    }
}

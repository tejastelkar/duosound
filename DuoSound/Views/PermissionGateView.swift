import SwiftUI

struct PermissionGateView: View {
    let onAllow: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            VStack(spacing: 6) {
                // Icon
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(
                            LinearGradient(
                                colors: [Color(red: 0.306, green: 0.627, blue: 1), Color(red: 0.039, green: 0.435, blue: 0.878)],
                                startPoint: .top, endPoint: .bottom
                            )
                        )
                        .frame(width: 64, height: 64)
                        .shadow(color: Color.blue.opacity(0.30), radius: 8, y: 4)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .strokeBorder(Color.white.opacity(0.3), lineWidth: 0.5)
                                .blendMode(.plusLighter)
                        )
                    Image(systemName: "headphones")
                        .font(.system(size: 28, weight: .regular))
                        .foregroundStyle(.white)
                }
                .padding(.bottom, 14)

                Text("Allow DuoSound to manage audio devices?")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Color.black.opacity(0.88))
                    .multilineTextAlignment(.center)

                Text("DuoSound creates and configures CoreAudio aggregate devices so you can play sound on two or more outputs at once. Your audio data is not recorded.")
                    .font(.system(size: 12.5))
                    .foregroundStyle(Color.black.opacity(0.55))
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
                    .frame(maxWidth: 340)
                    .padding(.top, 4)

                // Buttons
                HStack(spacing: 8) {
                    Button("Allow", action: onAllow)
                        .buttonStyle(PrimaryButtonStyle(disabled: false))
                }
                .padding(.top, 18)

                // Fine print
                HStack(spacing: 4) {
                    Image(systemName: "info.circle")
                        .font(.system(size: 10))
                    Text("CoreAudio device management requires no special system permissions.")
                }
                .font(.system(size: 10.5))
                .foregroundStyle(Color.black.opacity(0.4))
                .padding(.top, 12)
            }
            .padding(.horizontal, 32)
            Spacer()
        }
    }
}

import SwiftUI

enum BannerTone { case info, success, warn, error }

struct BannerColors {
    let bg: Color
    let stroke: Color
    let titleColor: Color
}

extension BannerTone {
    var colors: BannerColors {
        switch self {
        case .info:
            return BannerColors(
                bg: Color(red: 0, green: 0.478, blue: 1).opacity(0.08),
                stroke: Color(red: 0, green: 0.478, blue: 1).opacity(0.18),
                titleColor: Color(red: 0, green: 0.314, blue: 0.722)
            )
        case .success:
            return BannerColors(
                bg: Color(red: 0.098, green: 0.639, blue: 0.165).opacity(0.08),
                stroke: Color(red: 0.098, green: 0.639, blue: 0.165).opacity(0.18),
                titleColor: Color(red: 0.075, green: 0.467, blue: 0.165)
            )
        case .warn:
            return BannerColors(
                bg: Color(red: 0.788, green: 0.478, blue: 0.075).opacity(0.10),
                stroke: Color(red: 0.788, green: 0.478, blue: 0.075).opacity(0.22),
                titleColor: Color(red: 0.541, green: 0.322, blue: 0.031)
            )
        case .error:
            return BannerColors(
                bg: Color(red: 0.788, green: 0.239, blue: 0.169).opacity(0.08),
                stroke: Color(red: 0.788, green: 0.239, blue: 0.169).opacity(0.22),
                titleColor: Color(red: 0.604, green: 0.169, blue: 0.114)
            )
        }
    }
}

struct BannerAction {
    let label: String
    let isPrimary: Bool
    let action: () -> Void
}

struct BannerView: View {
    let tone: BannerTone
    let systemImage: String?
    let title: String
    let bodyText: String?
    let actions: [BannerAction]

    init(
        tone: BannerTone = .info,
        systemImage: String? = nil,
        title: String,
        body: String? = nil,
        actions: [BannerAction] = []
    ) {
        self.tone = tone
        self.systemImage = systemImage
        self.title = title
        self.bodyText = body
        self.actions = actions
    }

    var body: some View {
        let c = tone.colors
        HStack(alignment: .top, spacing: 10) {
            if let img = systemImage {
                Image(systemName: img)
                    .font(.system(size: 13))
                    .foregroundStyle(c.titleColor)
                    .padding(.top, 1)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(c.titleColor)
                if let b = bodyText {
                    Text(b)
                        .font(.system(size: 11.5))
                        .foregroundStyle(Color.black.opacity(0.65))
                        .fixedSize(horizontal: false, vertical: true)
                }
                if !actions.isEmpty {
                    HStack(spacing: 6) {
                        ForEach(Array(actions.enumerated()), id: \.offset) { _, act in
                            Button(act.label) { act.action() }
                                .buttonStyle(BannerButtonStyle(primary: act.isPrimary, titleColor: c.titleColor))
                        }
                    }
                    .padding(.top, 2)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(c.bg)
                .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(c.stroke, lineWidth: 0.5))
        )
        .padding(.horizontal, 14)
        .padding(.top, 12)
    }
}

private struct BannerButtonStyle: ButtonStyle {
    let primary: Bool
    let titleColor: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 11.5, weight: .medium))
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(primary ? titleColor : Color.black.opacity(0.06))
            .foregroundStyle(primary ? Color.white : Color.black.opacity(0.78))
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .opacity(configuration.isPressed ? 0.8 : 1)
    }
}

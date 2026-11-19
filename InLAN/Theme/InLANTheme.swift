import SwiftUI

struct InLANTheme {
    static let background = Color(red: 0.015, green: 0.019, blue: 0.018)
    static let headerBackground = Color(red: 0.035, green: 0.043, blue: 0.040)
    static let panel = Color(red: 0.055, green: 0.060, blue: 0.058)
    static let panelRaised = Color(red: 0.075, green: 0.080, blue: 0.078)
    static let selected = Color(red: 0.235, green: 0.240, blue: 0.238)
    static let border = Color.white.opacity(0.13)
    static let divider = Color.white.opacity(0.10)
    static let primaryText = Color.white.opacity(0.96)
    static let secondaryText = Color.white.opacity(0.60)
    static let tertiaryText = Color.white.opacity(0.38)
    static let yellow = Color(red: 1.0, green: 0.76, blue: 0.00)
    static let green = Color(red: 0.08, green: 0.78, blue: 0.31)
    static let amber = Color(red: 1.0, green: 0.61, blue: 0.00)
    static let red = Color(red: 1.0, green: 0.22, blue: 0.25)
    static let grey = Color(red: 0.54, green: 0.56, blue: 0.56)

    static let wordmarkGradient = LinearGradient(
        colors: [yellow, Color(red: 0.65, green: 0.78, blue: 0.09), green],
        startPoint: .leading,
        endPoint: .trailing
    )

    static let headerGradient = LinearGradient(
        colors: [headerBackground, background],
        startPoint: .top,
        endPoint: .bottom
    )

    static let pillGradient = LinearGradient(
        colors: [Color.white.opacity(0.035), Color.white.opacity(0.012)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static func statusColor(_ device: LANDevice) -> Color {
        if device.state == .online && (device.currentLatencyMS ?? 0) >= 30 { return yellow }
        return statusColor(device.state)
    }

    static func statusColor(_ state: ReachabilityState) -> Color {
        switch state {
        case .online: green
        case .onlineNoPing: grey
        case .offline: red
        case .unknown: grey
        }
    }
}

extension View {
    func inLANPanel(cornerRadius: CGFloat = 22) -> some View {
        self
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(InLANTheme.pillGradient)
                    .background(
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(InLANTheme.panel)
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(InLANTheme.border, lineWidth: 1)
            )
    }
}

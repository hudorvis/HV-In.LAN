import SwiftUI

struct AppWordmark: View {
    var compact = false

    var body: some View {
        VStack(spacing: compact ? 5 : 8) {
            HStack(spacing: 0) {
                Text("In")
                    .font(.system(size: compact ? 38 : 50, weight: .medium, design: .rounded))
                Text(".")
                    .font(.system(size: compact ? 38 : 50, weight: .semibold, design: .rounded))
                    .foregroundStyle(InLANTheme.yellow)
                Text("LAN")
                    .font(.system(size: compact ? 38 : 50, weight: .light, design: .rounded))
            }
            .foregroundStyle(InLANTheme.primaryText)

            Capsule()
                .fill(InLANTheme.wordmarkGradient)
                .frame(width: compact ? 72 : 92, height: 4)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("In dot LAN")
    }
}

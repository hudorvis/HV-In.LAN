import SwiftUI

struct BottomJoinedActions: View {
    let leftTitle: String
    let rightTitle: String
    let leftIcon: String
    let rightIcon: String
    var leftColor: Color = InLANTheme.yellow
    var rightColor: Color = InLANTheme.green
    let leftAction: () -> Void
    let rightAction: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            actionButton(title: leftTitle, icon: leftIcon, color: leftColor, action: leftAction)

            Rectangle()
                .fill(InLANTheme.divider)
                .frame(width: 1, height: 52)

            actionButton(title: rightTitle, icon: rightIcon, color: rightColor, action: rightAction)
        }
        .frame(height: 64)
        .inLANPanel(cornerRadius: 41)
    }

    private func actionButton(title: String, icon: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(color)
                Text(title)
                    .font(.system(size: 18, weight: .regular, design: .rounded))
                    .foregroundStyle(InLANTheme.primaryText)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.75)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityIdentifier("action-\(title)")
    }
}

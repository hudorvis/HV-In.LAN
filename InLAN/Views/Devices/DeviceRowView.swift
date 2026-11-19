import SwiftUI

struct DeviceRowView: View {
    let device: LANDevice
    var compact = false
    var showBookmark = false
    let onSelect: () -> Void
    let onToggleSaved: () -> Void

    var body: some View {
        HStack(spacing: 0) {
        Button(action: onSelect) {
            HStack(spacing: compact ? 6 : 10) {
                StatusDot(device: device, size: compact ? 11 : 13)

                DeviceIcon(kind: device.kind, size: compact ? 30 : 42)

                VStack(alignment: .leading, spacing: 3) {
                    Text(device.displayName)
                        .font(.system(size: compact ? 16 : 19, weight: .medium, design: .rounded))
                        .foregroundStyle(InLANTheme.primaryText)
                        .lineLimit(1)
                    Text(device.ipAddress)
                        .font(.system(size: compact ? 13 : 15, weight: .regular, design: .rounded))
                        .foregroundStyle(InLANTheme.secondaryText)
                }

                Spacer(minLength: 8)

                Text(device.latencyText)
                    .font(.system(size: compact ? 15 : 17, weight: .medium, design: .rounded))
                    .foregroundStyle(latencyColor)
                    .lineLimit(1)

                Sparkline(samples: device.samples, state: device.state)
                    .frame(width: compact ? 42 : 66, height: 26)
            }
            .padding(.horizontal, compact ? 14 : 18)
            .frame(minHeight: compact ? 70 : 88)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        if showBookmark {
            Button(action: onToggleSaved) {
                Image(systemName: "bookmark.fill").foregroundStyle(InLANTheme.yellow)
                    .frame(width: 44, height: 44)
            }.buttonStyle(.plain).accessibilityLabel("Remove from Monitor")
        }
        }
        .inLANPanel(cornerRadius: compact ? 18 : 22)
        .contextMenu {
            Button(device.isSaved ? "Remove from Saved" : "Save Device", action: onToggleSaved)
        }
    }

    private var latencyColor: Color {
        InLANTheme.statusColor(device)
    }
}

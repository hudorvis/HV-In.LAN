import SwiftUI

struct MonitorTileView: View {
    let device: LANDevice
    let compact: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: compact ? 10 : 14) {
                HStack(spacing: 12) {
                    DeviceIcon(kind: device.kind, size: compact ? 38 : 44)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(device.displayName)
                            .font(.system(size: compact ? 16 : 18, weight: .medium, design: .rounded))
                            .foregroundStyle(InLANTheme.primaryText)
                            .lineLimit(1)
                        Text(device.ipAddress)
                            .font(.system(size: compact ? 12 : 14, design: .rounded))
                            .foregroundStyle(InLANTheme.secondaryText)
                    }
                    Spacer(minLength: 4)
                    StatusDot(device: device, size: 11)
                }

                Text(device.statusText).font(.caption).foregroundStyle(metricColor)
                Divider().overlay(InLANTheme.divider)

                HStack(alignment: .firstTextBaseline) {
                    Text(device.currentLatencyMS.map { "\(Int($0.rounded())) ms" } ?? "— ms")
                        .font(.system(size: compact ? 19 : 23, weight: .medium, design: .rounded))
                        .foregroundStyle(metricColor)
                    Spacer()
                    Group {
                        Text(device.lossText + " ICMP loss")
                            .font(.system(size: compact ? 13 : 15, design: .rounded))
                            .foregroundStyle(metricColor)
                    }
                }

                Sparkline(samples: device.samples, state: device.state)
                    .frame(height: compact ? 28 : 40)
            }
            .padding(compact ? 14 : 18)
            .frame(maxWidth: .infinity, minHeight: compact ? 152 : 180, alignment: .topLeading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .inLANPanel(cornerRadius: 22)
    }

    private var metricColor: Color {
        InLANTheme.statusColor(device)
    }
}

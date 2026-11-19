import SwiftUI
import UIKit

struct DeviceDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var scanner: NetworkScanner
    @State private var renameText = ""
    @State private var showRename = false

    let deviceID: String

    private var device: LANDevice? {
        scanner.devices.first(where: { $0.id == deviceID })
    }

    var body: some View {
        ZStack {
            InLANTheme.background.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 16) {
                    AppWordmark(compact: true)
                        .padding(.top, 10)

                    HStack {
                        Button {
                            dismiss()
                        } label: {
                            Label(scanner.primaryMode.rawValue, systemImage: "chevron.left")
                                .font(.system(size: 16, weight: .medium, design: .rounded))
                                .foregroundStyle(InLANTheme.primaryText)
                                .padding(.horizontal, 16)
                                .frame(height: 46)
                                .inLANPanel(cornerRadius: 23)
                        }
                        .buttonStyle(.plain)
                        Spacer()
                    }

                    if let device {
                        if let hint = scanner.permissionHint { Text(hint).foregroundStyle(InLANTheme.secondaryText) }
                        header(device)
                        detailRows(device)
                        latencyChart(device)
                        services(device)
                        actions(device)
                    } else {
                        Text("Device no longer available")
                            .foregroundStyle(InLANTheme.secondaryText)
                            .frame(maxWidth: .infinity, minHeight: 300)
                            .inLANPanel()
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 120)
                .frame(maxWidth: 900)
                .frame(maxWidth: .infinity)
            }
            .safeAreaInset(edge: .bottom) {
                BottomJoinedActions(
                    leftTitle: "Copy IP",
                    rightTitle: scanner.pinging == deviceID ? "Pinging…" : "Ping",
                    leftIcon: "doc.on.doc",
                    rightIcon: "antenna.radiowaves.left.and.right",
                    leftColor: InLANTheme.primaryText,
                    rightColor: InLANTheme.green,
                    leftAction: { UIPasteboard.general.string = deviceID },
                    rightAction: { scanner.ping(deviceID) }
                )
                .padding(.horizontal, 20)
                .padding(.bottom, 8)
                .background(InLANTheme.background.opacity(0.96))
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .alert("Rename Device", isPresented: $showRename) {
            TextField("Device name", text: $renameText)
            Button("Cancel", role: .cancel) {}
            Button("Save") {
                guard let device else { return }
                scanner.rename(device, to: renameText)
            }
        }
    }

    private func header(_ device: LANDevice) -> some View {
        HStack(spacing: 16) {
            StatusDot(device: device, size: 15)
            DeviceIcon(kind: device.kind, size: 56)
            VStack(alignment: .leading, spacing: 4) {
                Text(device.displayName)
                    .font(.system(size: 25, weight: .semibold, design: .rounded))
                Text(device.ipAddress)
                    .font(.system(size: 16, design: .rounded))
                    .foregroundStyle(InLANTheme.secondaryText)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 8) {
                Text(device.latencyText)
                    .font(.system(size: 18, weight: .medium, design: .rounded))
                    .foregroundStyle(InLANTheme.statusColor(device))
                Sparkline(samples: device.samples, state: device.state)
                    .frame(width: 54, height: 32)
            }
        }
        .padding(20)
        .inLANPanel(cornerRadius: 24)
    }

    private func detailRows(_ device: LANDevice) -> some View {
        VStack(spacing: 0) {
            detailRow(icon: "rectangle.connected.to.line.below", title: "IP Address", value: device.ipAddress)
            divider
            detailRow(icon: "desktopcomputer", title: "Host Name", value: device.resolvedName ?? "Not resolved")
            divider
            detailRow(icon: "waveform.path", title: "Status", value: device.statusText, tint: detailTint(device))
            divider
            detailRow(icon: "clock", title: "Current Latency", value: device.currentLatencyMS.map { "\(Int($0.rounded())) ms" } ?? "—", tint: detailTint(device))
            divider
            detailRow(
                icon: "chart.line.uptrend.xyaxis",
                title: "Min / Average / Max",
                value: formatStats(device),
                tint: detailTint(device)
            )
            divider
            detailRow(icon: "percent", title: "ICMP Packet Loss", value: device.lossText, tint: detailTint(device))
            divider
            TimelineView(.periodic(from: .now, by: 5)) { context in
                detailRow(icon: "clock.arrow.circlepath", title: "Last Seen",
                          value: lastSeenText(device.lastSeen, now: context.date), tint: detailTint(device))
            }
        }
        .padding(.horizontal, 18)
        .inLANPanel(cornerRadius: 22)
    }

    private func detailRow(icon: String, title: String, value: String, tint: Color = InLANTheme.primaryText) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .light))
                .foregroundStyle(InLANTheme.primaryText)
                .frame(width: 28)
            Text(title)
                .font(.system(size: 16, design: .rounded))
                .foregroundStyle(InLANTheme.primaryText)
            Spacer()
            Text(value)
                .font(.system(size: 16, design: .rounded))
                .foregroundStyle(tint)
                .multilineTextAlignment(.trailing)
        }
        .padding(.vertical, 14)
    }

    private var divider: some View {
        Rectangle().fill(InLANTheme.divider).frame(height: 1)
    }

    private func latencyChart(_ device: LANDevice) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Latency History · Last 60 probes")
                    .font(.system(size: 18, weight: .medium, design: .rounded))
                Spacer()
                Text("ms").foregroundStyle(InLANTheme.secondaryText)
            }

            Sparkline(samples: device.samples, state: device.state, limit: 60)
            .frame(height: 180)
        }
        .padding(20)
        .inLANPanel(cornerRadius: 22)
    }

    private func services(_ device: LANDevice) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Services")
                .font(.system(size: 18, weight: .medium, design: .rounded))
                .padding(.horizontal, 18)
                .padding(.vertical, 14)

            divider
            let observations = device.serviceNames + device.openPorts.sorted().map { "TCP \($0) · last accepted" }
            if observations.isEmpty {
                Text("No services detected").foregroundStyle(InLANTheme.secondaryText).padding()
            } else {
                ForEach(observations, id: \.self) { item in
                    Text(item).padding(.horizontal, 18).padding(.vertical, 10)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .inLANPanel(cornerRadius: 22)
    }

    private func actions(_ device: LANDevice) -> some View {
        VStack(spacing: 0) {
            actionRow(icon: device.isSaved ? "bookmark.fill" : "bookmark", title: device.isSaved ? "Remove from Monitor" : "Save to Monitor") {
                scanner.toggleSaved(device)
            }
            divider
            actionRow(icon: "pencil", title: "Rename Device") {
                renameText = device.customName ?? device.displayName
                showRename = true
            }

        }
        .inLANPanel(cornerRadius: 22)
    }

    private func actionRow(icon: String, title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .foregroundStyle(InLANTheme.primaryText)
                    .frame(width: 26)
                Text(title)
                    .foregroundStyle(InLANTheme.primaryText)
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundStyle(InLANTheme.secondaryText)
            }
            .font(.system(size: 16, design: .rounded))
            .padding(.horizontal, 18)
            .padding(.vertical, 15)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func formatStats(_ device: LANDevice) -> String {
        guard let min = device.minLatencyMS,
              let average = device.averageLatencyMS,
              let max = device.maxLatencyMS else { return "—" }
        return "\(Int(min.rounded())) / \(Int(average.rounded())) / \(Int(max.rounded())) ms"
    }

    private func lastSeenText(_ date: Date?, now: Date) -> String {
        guard let date else { return "Never" }
        let seconds = Int(now.timeIntervalSince(date))
        if seconds < 10 { return "Just now" }
        if seconds < 60 { return "\(seconds)s ago" }
        return "\(seconds / 60)m ago"
    }

    private func detailTint(_ device: LANDevice) -> Color {
        InLANTheme.statusColor(device)
    }
}

import SwiftUI

struct DeviceListView: View {
    @EnvironmentObject private var scanner: NetworkScanner
    let availableWidth: CGFloat
    let isLandscape: Bool
    let isPad: Bool

    private var columns: [GridItem] {
        if isPad && availableWidth > 720 {
            return [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)]
        }
        if isLandscape && availableWidth > 760 {
            return [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]
        }
        return [GridItem(.flexible())]
    }

    var body: some View {
        VStack(spacing: 14) {
            let rows = scanner.filteredDevices
            networkStatus
            if let hint = scanner.permissionHint, !rows.isEmpty {
                Text(hint).font(.footnote).foregroundStyle(InLANTheme.secondaryText)
            }

            if rows.isEmpty {
                emptyState
            } else {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(rows) { device in
                        DeviceRowView(
                            device: device,
                            compact: availableWidth < 430 || columns.count > 1,
                            showBookmark: scanner.filter == .saved,
                            onSelect: { scanner.selectedDevice = device },
                            onToggleSaved: { scanner.toggleSaved(device) }
                        )
                    }
                }
            }
        }
    }

    private var networkStatus: some View {
        Button {
            scanner.showScanSetup = true
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "wifi")
                    .foregroundStyle(InLANTheme.secondaryText)
                Text(scanner.networkSnapshot.interfaceName == "Unavailable" ? "No active LAN" : scanner.networkSnapshot.displayRange)
                    .foregroundStyle(InLANTheme.secondaryText)
                Spacer()
                Text(scanner.statusText)
                    .foregroundStyle(statusColor)
                    .lineLimit(2)
            }
            .font(.system(size: 15, weight: .regular, design: .rounded))
            .padding(.horizontal, 18)
            .frame(height: 58)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("network-status")
        .inLANPanel(cornerRadius: 18)
    }

    private var statusColor: Color {
        switch scanner.scanState {
        case .failed: InLANTheme.red
        case .preparing, .scanning, .finishing: InLANTheme.yellow
        case .continuous: InLANTheme.green
        case .idle: InLANTheme.secondaryText
        }
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "network.slash")
                .font(.system(size: 42, weight: .light))
                .foregroundStyle(InLANTheme.tertiaryText)
            Text(scanner.filter == .saved ? "No saved devices" : scanner.filter == .online ? "No online devices" : "No devices found")
                .font(.system(size: 20, weight: .medium, design: .rounded))
                .foregroundStyle(InLANTheme.primaryText)
            Text(scanner.permissionHint ?? "Use Scan Once or Scan Continuously to discover devices on this local network.")
                .font(.system(size: 15, weight: .regular, design: .rounded))
                .foregroundStyle(InLANTheme.secondaryText)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 420)
        }
        .frame(maxWidth: .infinity, minHeight: 260)
        .inLANPanel(cornerRadius: 22)
    }
}

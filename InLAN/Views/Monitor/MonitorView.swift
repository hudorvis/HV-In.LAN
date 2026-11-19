import SwiftUI

struct MonitorView: View {
    @EnvironmentObject private var scanner: NetworkScanner
    let availableWidth: CGFloat
    let isLandscape: Bool
    let isPad: Bool

    private var columnCount: Int {
        if isPad && availableWidth > 1050 { return 3 }
        if availableWidth >= 480 { return 2 }
        return 1
    }

    private var columns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 14), count: columnCount)
    }

    var body: some View {
        let wall = scanner.monitoredDevices
        return VStack(spacing: 14) {
            HStack {
                Text("Live Monitor")
                Spacer()
                Text("\(wall.count) devices")
                Spacer()
                HStack(spacing: 7) {
                    Text(scanner.statusText)
                    if scanner.scanState.isRunning {
                        Image(systemName: "arrow.triangle.2.circlepath")
                    }
                }
                .foregroundStyle(scanner.scanState.isRunning ? InLANTheme.green : InLANTheme.secondaryText)
            }
            .font(.system(size: 15, design: .rounded))
            .foregroundStyle(InLANTheme.secondaryText)
            .padding(.horizontal, 6)

            if let hint = scanner.permissionHint, !wall.isEmpty {
                Text(hint).font(.footnote).foregroundStyle(InLANTheme.secondaryText)
            }
            if wall.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "rectangle.grid.2x2")
                        .font(.system(size: 42, weight: .light))
                        .foregroundStyle(InLANTheme.tertiaryText)
                    Text("No monitored devices")
                        .font(.system(size: 20, weight: .medium, design: .rounded))
                    Text(scanner.permissionHint ?? (scanner.filter == .online ? "No saved devices currently report online." : "Save devices from Devices to monitor them here."))
                        .foregroundStyle(InLANTheme.secondaryText)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, minHeight: 300)
                .inLANPanel(cornerRadius: 22)
            } else {
                LazyVGrid(columns: columns, spacing: 14) {
                    ForEach(wall) { device in
                        MonitorTileView(device: device, compact: columnCount >= 3) {
                            scanner.selectedDevice = device
                        }
                    }
                }
            }
        }
    }
}

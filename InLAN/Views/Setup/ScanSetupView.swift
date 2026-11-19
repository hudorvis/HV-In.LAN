import SwiftUI

struct ScanSetupView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var scanner: NetworkScanner

    var body: some View {
        ZStack {
            InLANTheme.background.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 18) {
                    AppWordmark(compact: true)
                        .padding(.top, 10)

                    HStack {
                        Button {
                            dismiss()
                        } label: {
                            Label("Devices", systemImage: "chevron.left")
                                .font(.system(size: 16, weight: .medium, design: .rounded))
                                .foregroundStyle(InLANTheme.primaryText)
                                .padding(.horizontal, 16)
                                .frame(height: 46)
                                .inLANPanel(cornerRadius: 23)
                        }
                        .buttonStyle(.plain)
                        Spacer()
                    }

                    sectionTitle("Scan Setup")
                    setupRows

                    sectionTitle("Scan Options")
                    scanOptions
                    if scanner.rangeMode == .custom {
                        VStack {
                            TextField("First IPv4 address", text: $scanner.customStart)
                            Divider()
                            TextField("Last IPv4 address", text: $scanner.customEnd)
                        }
                        .keyboardType(.decimalPad)
                        .padding().inLANPanel()
                    }
                    if let hint = scanner.permissionHint { Text(hint).foregroundStyle(InLANTheme.secondaryText) }

                    sectionTitle("Discovery Methods")
                    discoveryRows

                    HStack(spacing: 14) {
                        Image(systemName: "checkmark.shield")
                            .font(.system(size: 28, weight: .light))
                            .foregroundStyle(InLANTheme.green)
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Local Network Only")
                                .font(.system(size: 18, weight: .medium, design: .rounded))
                            Text("Saved devices and names stay on this device.")
                                .font(.system(size: 15, design: .rounded))
                                .foregroundStyle(InLANTheme.secondaryText)
                        }
                        Spacer()
                    }
                    .padding(20)
                    .inLANPanel(cornerRadius: 22)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 120)
                .frame(maxWidth: 900)
                .frame(maxWidth: .infinity)
            }
            .safeAreaInset(edge: .bottom) {
                BottomJoinedActions(
                    leftTitle: scanner.runMode == .once ? "Stop Scan" : "Scan Once",
                    rightTitle: scanner.runMode == .continuous ? "Stop Continuous" : "Scan Continuously",
                    leftIcon: "magnifyingglass",
                    rightIcon: "arrow.triangle.2.circlepath",
                    leftAction: {
                        dismiss()
                        scanner.runMode == .once ? scanner.stopScanning() : scanner.scanOnce()
                    },
                    rightAction: {
                        dismiss()
                        scanner.runMode == .continuous ? scanner.stopScanning() : scanner.startContinuous()
                    }
                )
                .padding(.horizontal, 20)
                .padding(.bottom, 8)
                .background(InLANTheme.background.opacity(0.96))
            }
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    private var setupRows: some View {
        VStack(spacing: 0) {
            setupRow(icon: "network", title: "Network", value: scanner.networkSnapshot.interfaceName)
            divider
            setupRow(icon: "rectangle.connected.to.line.below", title: "Detected IP", value: scanner.networkSnapshot.address)
            divider
            setupRow(icon: "point.3.connected.trianglepath.dotted", title: "Subnet Mask", value: scanner.networkSnapshot.netmask)
            divider
            setupRow(icon: "arrow.left.and.right", title: "Connected Subnet", value: scanner.networkSnapshot.displayRange)
            divider
            setupRow(icon: "gauge.with.dots.needle.33percent", title: "Scan Mode", value: scanner.rangeMode.rawValue)
        }
        .padding(.horizontal, 18)
        .inLANPanel(cornerRadius: 22)
    }

    private var scanOptions: some View {
        HStack(spacing: 0) {
            ForEach(ScanRangeMode.allCases) { mode in
                Button {
                    scanner.updateRangeMode(mode)
                } label: {
                    Text(mode.rawValue)
                        .font(.system(size: 14, weight: scanner.rangeMode == mode ? .medium : .regular, design: .rounded))
                        .foregroundStyle(scanner.rangeMode == mode ? InLANTheme.primaryText : InLANTheme.secondaryText)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(
                            RoundedRectangle(cornerRadius: 24, style: .continuous)
                                .fill(scanner.rangeMode == mode ? InLANTheme.selected : .clear)
                                .padding(4)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .inLANPanel(cornerRadius: 28)
    }

    private var discoveryRows: some View {
        VStack(spacing: 0) {
            discoveryRow(icon: "antenna.radiowaves.left.and.right", title: "Ping", status: "Enabled", active: true)
            divider
            discoveryRow(icon: "bonjour", title: "Bonjour", status: "Enabled", active: true)
            divider
            discoveryRow(icon: "dot.radiowaves.left.and.right", title: "SSDP", status: "Planned", active: false)
            divider
            discoveryRow(icon: "globe", title: "Reverse DNS", status: "Enabled", active: true)
            divider
            discoveryRow(icon: "arrow.right.circle", title: "TCP Probe", status: "Enabled", active: true)
        }
        .padding(.horizontal, 18)
        .inLANPanel(cornerRadius: 22)
    }

    private func sectionTitle(_ title: String) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 21, weight: .medium, design: .rounded))
                .foregroundStyle(InLANTheme.secondaryText)
            Spacer()
        }
        .padding(.horizontal, 4)
    }

    private func setupRow(icon: String, title: String, value: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .frame(width: 28)
                .foregroundStyle(InLANTheme.primaryText)
            Text(title)
                .foregroundStyle(InLANTheme.primaryText)
            Spacer()
            Text(value)
                .foregroundStyle(InLANTheme.secondaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .font(.system(size: 16, design: .rounded))
        .padding(.vertical, 15)
    }

    private func discoveryRow(icon: String, title: String, status: String, active: Bool) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .frame(width: 28)
                .foregroundStyle(InLANTheme.primaryText)
            Text(title)
            Spacer()
            Circle()
                .fill(active ? InLANTheme.green : InLANTheme.grey)
                .frame(width: 8, height: 8)
            Text(status)
                .foregroundStyle(InLANTheme.secondaryText)
        }
        .font(.system(size: 16, design: .rounded))
        .padding(.vertical, 15)
    }

    private var divider: some View {
        Rectangle().fill(InLANTheme.divider).frame(height: 1)
    }
}

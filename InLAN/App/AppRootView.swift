import SwiftUI
import UIKit

struct AppRootView: View {
    @EnvironmentObject private var scanner: NetworkScanner
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        GeometryReader { geometry in
            let isLandscape = geometry.size.width >= 540 && geometry.size.width > geometry.size.height
            let isPad = geometry.size.width >= 700 && geometry.size.height >= 500

            ZStack {
                InLANTheme.background.ignoresSafeArea()

                if isLandscape {
                    landscapeLayout(size: geometry.size, isPad: isPad)
                } else {
                    portraitLayout(size: geometry.size, isPad: isPad)
                }
            }
        }
        .sheet(item: $scanner.selectedDevice) { device in
            DeviceDetailView(deviceID: device.id)
                .environmentObject(scanner)
        }
        .sheet(isPresented: $scanner.showScanSetup) {
            ScanSetupView()
                .environmentObject(scanner)
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background {
                scanner.appBecameInactive()
            }
        }
    }

    private func portraitLayout(size: CGSize, isPad: Bool) -> some View {
        ScrollView {
            VStack(spacing: isPad ? 24 : 18) {
                AppWordmark(compact: false)
                    .padding(.top, isPad ? 36 : 18)

                modeControls(maxWidth: isPad ? 760 : .infinity)

                contentView(
                    availableWidth: isPad ? min(size.width, 1000) - 64 : size.width - 40,
                    isLandscape: false,
                    isPad: isPad
                )
            }
            .padding(.horizontal, isPad ? 32 : 20)
            .padding(.bottom, 12)
            .frame(maxWidth: isPad ? 1000 : .infinity)
            .frame(maxWidth: .infinity)
        }
        .background(
            VStack {
                InLANTheme.headerGradient.frame(height: isPad ? 300 : 250)
                Spacer()
            }
            .ignoresSafeArea()
        )
        .safeAreaInset(edge: .bottom) {
            scanActions
                .padding(.horizontal, isPad ? 42 : 20)
                .padding(.bottom, 8)
                .frame(maxWidth: isPad ? 920 : .infinity)
                .frame(maxWidth: .infinity)
                .background(InLANTheme.background.opacity(0.96))
        }
    }

    private func landscapeLayout(size: CGSize, isPad: Bool) -> some View {
        let paneWidth = isPad ? min(410, size.width * 0.34) : min(320, max(232, size.width * 0.38))

        return HStack(spacing: 0) {
            ScrollView { VStack(spacing: isPad ? 24 : 12) {
                AppWordmark(compact: !isPad)
                    .padding(.top, isPad ? 24 : 12)

                modeControls(maxWidth: paneWidth - 40, compact: size.height < 440)

                Spacer(minLength: 8)

                scanActions
            }
            .padding(.horizontal, isPad ? 28 : 20)
            .padding(.bottom, isPad ? 24 : 12)
            .frame(minHeight: size.height)
            }
            .frame(width: paneWidth)
            .background(InLANTheme.headerGradient)

            Rectangle()
                .fill(InLANTheme.divider)
                .frame(width: 1)

            ScrollView {
                contentView(
                    availableWidth: size.width - paneWidth - 1 - (isPad ? 52 : 32),
                    isLandscape: true,
                    isPad: isPad
                )
                .padding(.horizontal, isPad ? 26 : 16)
                .padding(.vertical, isPad ? 24 : 14)
            }
        }
    }

    @ViewBuilder
    private func contentView(availableWidth: CGFloat, isLandscape: Bool, isPad: Bool) -> some View {
        switch scanner.primaryMode {
        case .devices:
            DeviceListView(availableWidth: availableWidth, isLandscape: isLandscape, isPad: isPad)
        case .monitor:
            MonitorView(availableWidth: availableWidth, isLandscape: isLandscape, isPad: isPad)
        }
    }

    private func modeControls(maxWidth: CGFloat, compact: Bool = false) -> some View {
        VStack(spacing: compact ? 8 : 16) {
            JoinedPillPicker(
                options: PrimaryMode.allCases,
                selection: $scanner.primaryMode,
                title: { $0.rawValue },
                height: compact ? 44 : 66
            )

            JoinedPillPicker(
                options: DeviceFilter.allCases,
                selection: $scanner.filter,
                title: { $0.rawValue },
                height: compact ? 44 : 58
            )
        }
        .frame(maxWidth: maxWidth)
    }

    private var scanActions: some View {
        BottomJoinedActions(
            leftTitle: scanner.runMode == .once ? "Stop Scan" : "Scan Once",
            rightTitle: scanner.runMode == .continuous ? "Stop Continuous" : "Scan Continuously",
            leftIcon: "magnifyingglass",
            rightIcon: scanner.runMode == .continuous ? "stop.fill" : "arrow.triangle.2.circlepath",
            leftAction: { scanner.runMode == .once ? scanner.stopScanning() : scanner.scanOnce() },
            rightAction: {
                if scanner.runMode == .continuous {
                    scanner.stopScanning()
                } else {
                    scanner.startContinuous()
                }
            }
        )
    }
}

#if DEBUG
#Preview("iPhone Portrait") {
    AppRootView()
        .environmentObject(NetworkScanner.preview)
        .frame(width: 393, height: 852)
}

#Preview("iPhone Landscape") {
    AppRootView()
        .environmentObject(NetworkScanner.preview)
        .frame(width: 852, height: 393)
}

#Preview("iPad Portrait") {
    AppRootView()
        .environmentObject(NetworkScanner.preview)
        .frame(width: 834, height: 1194)
}

#Preview("iPad Landscape") {
    AppRootView()
        .environmentObject(NetworkScanner.preview)
        .frame(width: 1194, height: 834)
}
#endif

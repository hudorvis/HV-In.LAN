import SwiftUI

struct StatusDot: View {
    let device: LANDevice
    var size: CGFloat = 13

    var body: some View {
        Circle()
            .fill(InLANTheme.statusColor(device))
            .frame(width: size, height: size)
            .shadow(color: InLANTheme.statusColor(device).opacity(device.state == .online ? 0.42 : 0), radius: 5)
    }
}

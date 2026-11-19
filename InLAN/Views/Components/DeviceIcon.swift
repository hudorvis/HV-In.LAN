import SwiftUI

struct DeviceIcon: View {
    let kind: DeviceKind
    var size: CGFloat = 46

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.white.opacity(0.025))
                .overlay(Circle().stroke(InLANTheme.border, lineWidth: 1))

            Image(systemName: kind.symbolName)
                .font(.system(size: size * 0.42, weight: .light))
                .foregroundStyle(InLANTheme.primaryText)
        }
        .frame(width: size, height: size)
    }
}

import SwiftUI

struct Sparkline: View {
    let samples: [LatencySample]
    let state: ReachabilityState
    var limit = 30

    var body: some View {
        Canvas { context, size in
            let window = Array(samples.suffix(limit))
            let maximum = max(window.compactMap(\.milliseconds).max() ?? 1, 1)
            let colour = InLANTheme.statusColor(state)
            var path = Path()
            var previous: CGPoint?
            for (i, sample) in window.enumerated() {
                guard let value = sample.milliseconds else { previous = nil; continue }
                let x = 2 + CGFloat(i) / CGFloat(max(window.count - 1, 1)) * max(0, size.width - 4)
                let y = 2 + (1 - CGFloat(value / maximum)) * max(0, size.height - 4)
                let point = CGPoint(x: x, y: y)
                if previous == nil { path.move(to: point) } else { path.addLine(to: point) }
                context.fill(Path(ellipseIn: CGRect(x: x-1.5, y: y-1.5, width: 3, height: 3)), with: .color(colour))
                previous = point
            }
            context.stroke(path, with: .color(colour), lineWidth: 1.5)
        }
        .accessibilityHidden(true)
    }
}

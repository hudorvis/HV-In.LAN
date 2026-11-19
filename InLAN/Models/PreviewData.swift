#if DEBUG
import Foundation

extension NetworkScanner {
    @MainActor
    static var preview: NetworkScanner {
        let scanner = NetworkScanner(observeNetwork: false)
        scanner.networkSnapshot = NetworkSnapshot(
            interfaceName: "Wi‑Fi",
            interfaceIndex: 1,
            subnet: IPv4Subnet(address: "192.168.1.84", netmask: "255.255.255.0")
        )
        scanner.devices = [
            previewDevice("192.168.1.1", "Studio Router", .router, 1),
            previewDevice("192.168.1.10", "FlyCam‑MacBook", .laptop, 2),
            previewDevice("192.168.1.20", "ATEM Switcher", .switcher, 2, saved: true),
            previewDevice("192.168.1.40", "Graphics PC", .desktop, 9),
            previewDevice("192.168.1.60", "Camera CCU", .camera, 4, saved: true),
            previewDevice("192.168.1.70", "Replay Server", .server, 6, saved: true),
            previewDevice("192.168.1.80", "Audio Console", .audio, 6),
            previewDevice("192.168.1.90", "Edit Suite iMac", .desktop, 9)
        ]
        return scanner
    }

    private static func previewDevice(
        _ ip: String,
        _ name: String,
        _ kind: DeviceKind,
        _ latency: Double,
        saved: Bool = false
    ) -> LANDevice {
        let values = (0..<24).map { index in
            LatencySample(milliseconds: latency + Double((index * 7) % 5) * 0.35)
        }
        return LANDevice(
            ipAddress: ip,
            resolvedName: name,
            state: .online,
            kind: kind,
            currentLatencyMS: latency,
            minLatencyMS: latency,
            averageLatencyMS: latency + 0.6,
            maxLatencyMS: latency + 3,
            packetLoss: 0,
            lastSeen: Date(),
            openPorts: [80],
            samples: values,
            isSaved: saved
        )
    }
}
#endif

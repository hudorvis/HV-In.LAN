import Foundation

struct LatencySample: Codable, Hashable, Identifiable {
    let id: UUID
    let date: Date
    let milliseconds: Double?

    init(date: Date = Date(), milliseconds: Double?) {
        self.id = UUID()
        self.date = date
        self.milliseconds = milliseconds
    }
}

enum ReachabilityState: String, Codable, Hashable {
    case online
    case onlineNoPing
    case offline
    case unknown
}

enum DeviceKind: String, Codable, CaseIterable {
    case router
    case laptop
    case switcher
    case camera
    case server
    case audio
    case desktop
    case printer
    case encoder
    case unknown

    var symbolName: String {
        switch self {
        case .router: "wifi.router"
        case .laptop: "laptopcomputer"
        case .switcher: "network"
        case .camera: "video"
        case .server: "server.rack"
        case .audio: "slider.horizontal.3"
        case .desktop: "desktopcomputer"
        case .printer: "printer"
        case .encoder: "play.rectangle"
        case .unknown: "questionmark.square.dashed"
        }
    }
}

struct LANDevice: Codable, Hashable, Identifiable {
    var id: String { ipAddress }

    var ipAddress: String
    var resolvedName: String?
    var customName: String?
    var state: ReachabilityState
    var kind: DeviceKind
    var currentLatencyMS: Double?
    var minLatencyMS: Double?
    var averageLatencyMS: Double?
    var maxLatencyMS: Double?
    var packetLoss: Double
    var lastSeen: Date?
    var openPorts: [UInt16]
    var samples: [LatencySample]
    var isSaved: Bool
    var serviceNames: [String]

    init(
        ipAddress: String,
        resolvedName: String? = nil,
        customName: String? = nil,
        state: ReachabilityState = .unknown,
        kind: DeviceKind = .unknown,
        currentLatencyMS: Double? = nil,
        minLatencyMS: Double? = nil,
        averageLatencyMS: Double? = nil,
        maxLatencyMS: Double? = nil,
        packetLoss: Double = 0,
        lastSeen: Date? = nil,
        openPorts: [UInt16] = [],
        samples: [LatencySample] = [],
        isSaved: Bool = false,
        serviceNames: [String] = []
    ) {
        self.ipAddress = ipAddress
        self.resolvedName = resolvedName
        self.customName = customName
        self.state = state
        self.kind = kind
        self.currentLatencyMS = currentLatencyMS
        self.minLatencyMS = minLatencyMS
        self.averageLatencyMS = averageLatencyMS
        self.maxLatencyMS = maxLatencyMS
        self.packetLoss = packetLoss
        self.lastSeen = lastSeen
        self.openPorts = openPorts
        self.samples = samples
        self.isSaved = isSaved
        self.serviceNames = serviceNames
    }

    var displayName: String {
        if let customName, !customName.isEmpty { return customName }
        if let resolvedName, !resolvedName.isEmpty { return resolvedName }
        return "Unknown Device"
    }

    var latencyText: String {
        switch state {
        case .online:
            if let currentLatencyMS { return "\(Int(currentLatencyMS.rounded())) ms" }
            return "Online"
        case .onlineNoPing:
            return "No Ping"
        case .offline:
            return "Offline"
        case .unknown:
            return "Waiting"
        }
    }

    mutating func observeService(at date: Date) {
        if lastSeen.map({ date > $0 }) ?? true { lastSeen = date }
        if state != .online {
            state = .onlineNoPing
            currentLatencyMS = nil
        }
    }

    mutating func record(milliseconds: Double?, tcpReply: Bool = false, serviceSeenAt: Date? = nil,
                         echoSent: Bool = true, tcpChecked: Bool = false, now: Date = Date()) {
        if echoSent { samples.append(LatencySample(date: now, milliseconds: milliseconds)) }
        if samples.count > 60 {
            samples.removeFirst(samples.count - 60)
        }

        if let milliseconds {
            state = .online
            currentLatencyMS = milliseconds
            lastSeen = now
        } else if tcpReply {
            state = .onlineNoPing
            currentLatencyMS = nil
            lastSeen = now
        } else if let serviceSeenAt {
            state = .onlineNoPing
            currentLatencyMS = nil
            observeService(at: serviceSeenAt)
        } else {
            state = (echoSent || tcpChecked) && (lastSeen != nil || isSaved) ? .offline : .unknown
            currentLatencyMS = nil
        }

        let successful = samples.compactMap(\.milliseconds)
        minLatencyMS = successful.min()
        maxLatencyMS = successful.max()
        averageLatencyMS = successful.isEmpty ? nil : successful.reduce(0, +) / Double(successful.count)

        let lost = samples.filter { $0.milliseconds == nil }.count
        packetLoss = samples.isEmpty ? 0 : (Double(lost) / Double(samples.count)) * 100
    }
}

extension LANDevice {
    var statusText: String {
        switch state {
        case .online: (currentLatencyMS ?? 0) >= 30 ? "High latency" : "Online"
        case .onlineNoPing: "Online · No Ping"
        case .offline: "Offline"
        case .unknown: "Unchecked"
        }
    }
    var lossText: String { samples.isEmpty ? "—" : "\(Int(packetLoss.rounded()))%" }
}

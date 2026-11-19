import Foundation
import SwiftUI
import Network

@MainActor
final class NetworkScanner: ObservableObject {
    enum ScanState: Equatable {
        case idle
        case preparing
        case finishing
        case scanning(completed: Int, total: Int)
        case continuous
        case failed(String)

        var isRunning: Bool {
            switch self {
            case .preparing, .scanning, .finishing, .continuous: true
            default: false
            }
        }
    }

    @Published var devices: [LANDevice] = []
    @Published var primaryMode: PrimaryMode = .devices
    @Published var filter: DeviceFilter = .all
    @Published var scanState: ScanState = .idle
    @Published var networkSnapshot: NetworkSnapshot = .unavailable
    @Published var rangeMode: ScanRangeMode = .automatic
    @Published var selectedDevice: LANDevice?
    @Published var showScanSetup = false
    @Published var permissionHint: String?

    private let pathMonitor = NWPathMonitor()
    private var interfaces: [NWInterface] = []
    private var currentNetwork: NetworkSnapshot {
        LocalNetworkInfo.currentSnapshot(interfaces: interfaces.map(\.name))
    }

    private let store: DeviceStore
    private var continuousTask: Task<Void, Never>?
    private let bonjour = BonjourDiscovery()
    private var epoch = UUID()
    private var names: [String: Task<Void, Never>] = [:]
    private var lastLookup: [String: Date] = [:]
    private var advertised: [String: [BonjourDiscovery.Advertisement]] = [:]
    private var probes: [String: Task<Void, Never>] = [:]
    private var monitorTask: Task<Void, Never>?
    @Published private(set) var runMode: ScanRunMode?
    @Published private(set) var pinging: String?
    @Published var customStart = ""
    @Published var customEnd = ""
    @Published private var completedOnce = false

    init(observeNetwork: Bool = true) {
        store = DeviceStore(defaults: observeNetwork ? .standard : nil)
        devices = store.load().map { old in
            var d = old
            d.state = .unknown
            d.currentLatencyMS = nil
            d.serviceNames = []
            return d
        }
        networkSnapshot = currentNetwork
        if observeNetwork {
            pathMonitor.pathUpdateHandler = { [weak self] path in
                Task { @MainActor in
                    guard let self else { return }
                    self.interfaces = path.availableInterfaces.filter { $0.type == .wiredEthernet || $0.type == .wifi }
                    let next = self.currentNetwork
                    guard next != self.networkSnapshot else { return }
                    if self.runMode != nil {
                        self.fail("Network changed", hint: "Start a new scan on the current LAN.")
                    }
                    self.changeNetwork(to: next)
                }
            }
            pathMonitor.start(queue: .main)
        }
    }

    deinit {
        pathMonitor.cancel()
        continuousTask?.cancel()
    }

    var filteredDevices: [LANDevice] {
        devices
            .filter { device in
                switch filter {
                case .all: true
                case .online: device.state == .online || device.state == .onlineNoPing
                case .saved: device.isSaved
                }
            }
            .sorted(by: deviceSort)
    }

    var monitoredDevices: [LANDevice] {
        let saved = devices.filter(\.isSaved)
        return saved.filter { filter != .online || $0.state == .online || $0.state == .onlineNoPing }
            .sorted(by: deviceSort)
    }

    var statusText: String {
        switch scanState {
        case .idle:
            return completedOnce ? "Scan complete" : "Ready to scan"
        case .preparing: return "Waiting for local network"
        case .finishing: return "Finishing discovery"
        case let .scanning(completed, total):
            return "Scanning \(completed)/\(total)"
        case .continuous:
            return "Refreshing"
        case let .failed(message):
            return message
        }
    }

    func scanOnce() { start(.once) }
    func startContinuous() { start(.continuous) }

    func stopScanning() {
        epoch = UUID()
        continuousTask?.cancel()
        continuousTask = nil
        monitorTask?.cancel()
        monitorTask = nil
        for job in probes.values { job.cancel() }
        for job in names.values { job.cancel() }
        probes.removeAll()
        names.removeAll()
        bonjour.stop()
        advertised.removeAll()
        runMode = nil
        pinging = nil
        scanState = .idle
        permissionHint = nil
        store.save(devices)
    }

    private func fail(_ message: String, hint: String) {
        stopScanning()
        scanState = .failed(message)
        permissionHint = hint
    }

    func ping(_ ip: String) {
        guard pinging == nil else { return }
        if runMode == nil { start(.once, single: ip); return }
        guard continuousTask != nil, let value = IPv4.value(ip), networkSnapshot.isPeer(value) else { return }
        pinging = ip
        let token = epoch
        Task {
            await probe(ip, token)
            if epoch == token { pinging = nil }
        }
    }

    private func start(_ mode: ScanRunMode, single: String? = nil) {
        stopScanning()
        completedOnce = false
        let network = currentNetwork
        if network != networkSnapshot { changeNetwork(to: network) }
        guard let subnet = network.subnet else {
            fail("No active LAN", hint: "Connect to Wi-Fi or Ethernet, then scan again.")
            return
        }
        var addresses: [UInt32]
        if let single {
            guard let ip = IPv4.value(single), network.isPeer(ip) else {
                fail("Outside this LAN", hint: "Connect to the device’s network to ping it.")
                return
            }
            addresses = [ip]
        } else {
            do {
                addresses = try subnet.targets(mode: rangeMode, start: customStart, end: customEnd)
            } catch IPv4Subnet.RangeError.tooLarge {
                fail("Range too large", hint: "Full Subnet supports /16 or smaller networks. Select Quick /24 or Custom Range.")
                return
            } catch {
                fail("Invalid range", hint: "Enter up to 4,094 consecutive addresses on this LAN in Scan Setup.")
                return
            }
            let saved = devices.filter(\.isSaved).compactMap { IPv4.value($0.ipAddress) }.filter(network.isPeer)
            let priority = Set(saved)
            addresses = saved + addresses.filter { !priority.contains($0) }
        }
        for i in devices.indices where (single == nil || devices[i].id == single) && !devices[i].serviceNames.isEmpty {
            devices[i].serviceNames.removeAll()
        }
        runMode = mode
        pinging = single
        scanState = .preparing
        let token = epoch
        let targets = addresses
        let interface = interfaces.first { $0.name == network.interfaceName }
        bonjour.start(on: network, interface: interface, availability: { [weak self] state in
            guard let self, self.epoch == token else { return }
            switch state {
            case .ready, .unicastOnly:
                self.permissionHint = state == .unicastOnly ? "Bonjour is unavailable. ICMP and TCP discovery are active." : nil
                guard self.continuousTask == nil else { return }
                self.continuousTask = Task { await self.run(targets, mode, token) }
            case .waitingForAccess, .waitingForNetwork:
                let hint = state == .waitingForAccess
                    ? "Allow In.LAN in the Local Network prompt or in Settings → Privacy & Security → Local Network."
                    : "Waiting for the selected Wi-Fi or Ethernet interface."
                if self.continuousTask == nil {
                    // Keep the first user's browse alive while the system alert is onscreen.
                    self.permissionHint = hint
                } else {
                    self.resetLiveStates()
                    self.fail("Scan interrupted", hint: hint + " Start a new scan when ready.")
                }
            case .denied:
                self.resetLiveStates()
                self.fail("Local Network access", hint: "Enable In.LAN in Settings → Privacy & Security → Local Network, then scan again.")
            }
        }, changed: { [weak self] address, rows in
            let ip = IPv4.string(address)
            guard let self, self.epoch == token, single == nil || single == ip else { return }
            self.advertised[ip] = rows.isEmpty ? nil : rows
            guard !rows.isEmpty || self.devices.contains(where: { $0.id == ip }) else { return }
            self.update(ip) { device in
                device.serviceNames = Array(Set(rows.map(\.label))).sorted()
                if let first = rows.first, let seenAt = rows.map(\.observedAt).max() {
                    device.resolvedName = first.hostname
                    device.observeService(at: seenAt)
                }
            }
            if self.continuousTask != nil { self.scheduleProbe(ip, token) }
        })
    }

    private func run(_ targets: [UInt32], _ mode: ScanRunMode, _ token: UUID) async {
        guard epoch == token, !Task.isCancelled else { return }
        if mode == .continuous {
            monitorTask = Task {
                while epoch == token && !Task.isCancelled {
                    let saved = devices.filter(\.isSaved).compactMap { IPv4.value($0.ipAddress) }
                    await pass(saved, limit: 4, progress: false, token: token)
                    try? await Task.sleep(for: .seconds(2))
                }
            }
        }
        var nextSweep = ContinuousClock.now
        repeat {
            guard epoch == token, !Task.isCancelled else { return }
            guard currentNetwork == networkSnapshot else {
                resetLiveStates()
                fail("Network changed", hint: "Start a new scan on the current LAN.")
                return
            }
            if ContinuousClock.now >= nextSweep {
                scanState = .scanning(completed: 0, total: targets.count)
                let earliestFinish = ContinuousClock.now.advanced(by: .seconds(2))
                await pass(targets, limit: 12, progress: true, token: token)
                try? await Task.sleep(until: earliestFinish, clock: .continuous)
                nextSweep = ContinuousClock.now.advanced(by: .seconds(30))
            } else {
                let known = devices.filter { !$0.isSaved }.compactMap { IPv4.value($0.ipAddress) }
                await pass(known, limit: 12, progress: false, token: token)
            }
            guard epoch == token else { return }
            if mode == .once {
                scanState = .finishing
                await bonjour.finish()
                // Service resolution can enqueue a probe, which can enqueue a reverse lookup.
                // Drain in that order before committing the final results.
                while epoch == token && (!probes.isEmpty || !names.isEmpty) {
                    for job in Array(probes.values) + Array(names.values) { await job.value }
                }
                guard epoch == token else { return }
                stopScanning()
                completedOnce = true
                return
            }
            store.save(devices)
            scanState = .continuous
            try? await Task.sleep(for: .seconds(2))
        } while !Task.isCancelled
    }

    private func pass(_ addresses: [UInt32], limit: Int, progress: Bool, token: UUID) async {
        var iterator = addresses.makeIterator()
        var completed = 0
        await withTaskGroup(of: Void.self) { group in
            for ip in addresses.prefix(limit) {
                _ = iterator.next()
                group.addTask { await self.probe(IPv4.string(ip), token) }
            }
            while await group.next() != nil {
                guard epoch == token, !Task.isCancelled else { group.cancelAll(); return }
                completed += 1
                if progress && (completed % 4 == 0 || completed == addresses.count) {
                    scanState = .scanning(completed: completed, total: addresses.count)
                }
                if completed % 32 == 0 && currentNetwork != networkSnapshot {
                    resetLiveStates()
                    fail("Network changed", hint: "Start a new scan on the current LAN.")
                    group.cancelAll()
                    return
                }
                if let ip = iterator.next() { group.addTask { await self.probe(IPv4.string(ip), token) } }
            }
        }
    }

    private func probe(_ ip: String, _ token: UUID) async {
        guard !Task.isCancelled else { return }
        if let job = scheduleProbe(ip, token) { await job.value }
    }

    @discardableResult
    private func scheduleProbe(_ ip: String, _ token: UUID) -> Task<Void, Never>? {
        guard epoch == token, let value = IPv4.value(ip), networkSnapshot.isPeer(value) else { return nil }
        if let existing = probes[ip] { return existing }
        let network = networkSnapshot
        let port = advertised[ip]?.first?.port ?? devices.first(where: { $0.id == ip })?.openPorts.first
        let job = Task {
            defer { if epoch == token { probes[ip] = nil } }
            guard let r = await ICMPPingService.probe(value, on: network, preferredPort: port),
                  epoch == token, !Task.isCancelled else { return }
            if r.denied && !r.hasReply {
                resetLiveStates()
                fail("Local Network access", hint: "Allow Local Network in Settings, then scan again.")
                return
            }
            guard !r.localError || r.hasReply else { return }
            let serviceSeenAt = advertised[ip]?.map(\.observedAt).max()
            let live = r.hasReply || serviceSeenAt != nil
            guard live || devices.contains(where: { $0.id == ip }) else { return }
            update(ip) { device in
                device.record(milliseconds: r.latency, tcpReply: r.refused || r.port != nil,
                              serviceSeenAt: serviceSeenAt, echoSent: r.sentEcho, tcpChecked: r.tcpChecked)
                if let p = r.port, !device.openPorts.contains(p) { device.openPorts.append(p) }
            }
            if live && advertised[ip] == nil && names[ip] == nil && Date().timeIntervalSince(lastLookup[ip] ?? .distantPast) > 90 {
                names[ip] = Task {
                    let name = await ReverseDNSResolver.resolve(value, on: network.interfaceIndex)
                    guard epoch == token, !Task.isCancelled else { return }
                    lastLookup[ip] = Date()
                    if let name, advertised[ip] == nil { update(ip) { $0.resolvedName = name } }
                    names[ip] = nil
                }
            }
        }
        probes[ip] = job
        return job
    }

    private func update(_ ip: String, _ edit: (inout LANDevice) -> Void) {
        let index = devices.firstIndex { $0.id == ip }
        var device = index.map { devices[$0] } ?? LANDevice(ipAddress: ip)
        edit(&device)
        device.kind = DeviceClassifier.classify(name: device.displayName, openPorts: device.openPorts)
        if let index { devices[index] = device } else { devices.append(device) }
    }

    private func resetLiveStates() {
        for index in devices.indices {
            devices[index].state = .unknown
            devices[index].currentLatencyMS = nil
            devices[index].serviceNames = []
        }
        lastLookup.removeAll()
    }

    private func changeNetwork(to network: NetworkSnapshot) {
        devices.removeAll { !$0.isSaved && $0.customName == nil }
        resetLiveStates()
        completedOnce = false
        networkSnapshot = network
    }

    func toggleSaved(_ device: LANDevice) {
        guard let index = devices.firstIndex(where: { $0.id == device.id }) else { return }
        devices[index].isSaved.toggle()
        store.save(devices)
    }

    func rename(_ device: LANDevice, to name: String) {
        guard let index = devices.firstIndex(where: { $0.id == device.id }) else { return }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        devices[index].customName = trimmed.isEmpty ? nil : trimmed
        store.save(devices)
    }

    func updateRangeMode(_ mode: ScanRangeMode) {
        rangeMode = mode
    }

    func appBecameInactive() {
        stopScanning()
        resetLiveStates()
    }

    private func deviceSort(_ lhs: LANDevice, _ rhs: LANDevice) -> Bool {
        (IPv4.value(lhs.ipAddress) ?? 0) < (IPv4.value(rhs.ipAddress) ?? 0)
    }
}

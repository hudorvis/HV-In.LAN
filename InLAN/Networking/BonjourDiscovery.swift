import Foundation
import Network

@MainActor
final class BonjourDiscovery {
    enum Availability: Equatable { case ready, waitingForAccess, waitingForNetwork, denied, unicastOnly }

    struct Advertisement: Sendable {
        let hostname: String
        let instance: String
        let type: String
        let port: UInt16
        let observedAt: Date

        var label: String { "\(instance) · \(type) · \(port)" }
    }

    private struct Service: Hashable, Sendable {
        let name: String
        let type: String
        let domain: String
    }

    private struct Resolution: Sendable {
        let addresses: Set<UInt32>
        let advertisement: Advertisement
    }

    private var browsers: [NWBrowser] = []
    private var members: Set<Service> = []
    private var resolved: [Service: Resolution] = [:]
    private var jobs: [Service: Task<Void, Never>] = [:]
    private var nextLookup: [Service: ContinuousClock.Instant] = [:]
    private var refreshTask: Task<Void, Never>?
    private var network = NetworkSnapshot.unavailable
    private var changed: ((UInt32, [Advertisement]) -> Void)?
    private var generation = UUID()
    private var browsing = false

    func start(on network: NetworkSnapshot, interface: NWInterface?,
               availability: @escaping (Availability) -> Void,
               changed: @escaping (UInt32, [Advertisement]) -> Void) {
        stop()
        self.network = network
        self.changed = changed
        let token = generation
        let types = Bundle.main.object(forInfoDictionaryKey: "NSBonjourServices") as? [String] ?? []
        guard let primary = types.first else { availability(.unicastOnly); return }
        browsing = true

        for type in types {
            let parameters = NWParameters.tcp
            parameters.requiredInterface = interface
            let browser = NWBrowser(for: .bonjour(type: type, domain: "local."), using: parameters)
            browsers.append(browser)
            if type == primary {
                browser.stateUpdateHandler = { [weak self] state in
                    // Every browser below delivers on the main queue. Process events in order.
                    MainActor.assumeIsolated {
                        guard let self, self.browsing, self.generation == token else { return }
                        switch state {
                        case .ready: availability(.ready)
                        case .waiting(let error):
                            availability(Self.policyDenied(error) ? .waitingForAccess : .waitingForNetwork)
                        case .failed(let error):
                            availability(Self.policyDenied(error) ? .denied : .unicastOnly)
                        default: break
                        }
                    }
                }
            }
            browser.browseResultsChangedHandler = { [weak self] results, _ in
                MainActor.assumeIsolated {
                    guard let self, self.browsing, self.generation == token else { return }
                    let current = Set(results.compactMap { result -> Service? in
                        guard case let .service(name, _, domain, endpointInterface) = result.endpoint,
                              endpointInterface == nil || endpointInterface?.name == network.interfaceName else { return nil }
                        return Service(name: name, type: type, domain: domain)
                    })
                    self.apply(current, type: type)
                }
            }
            browser.start(queue: .main)
        }

        refreshTask = Task { [weak self] in
            while !Task.isCancelled {
                do { try await Task.sleep(for: .seconds(2)) } catch { return }
                guard let self, self.browsing, self.generation == token else { return }
                self.scheduleDue()
            }
        }
    }

    private static func policyDenied(_ error: NWError) -> Bool {
        guard case .dns(let code) = error else { return false }
        return Int(code) == Int(kDNSServiceErr_PolicyDenied)
    }

    private func apply(_ current: Set<Service>, type: String) {
        for key in members.filter({ $0.type == type && !current.contains($0) }) {
            members.remove(key)
            jobs.removeValue(forKey: key)?.cancel()
            nextLookup[key] = nil
            if let old = resolved.removeValue(forKey: key) { publish(old.addresses) }
        }
        members.formUnion(current)
        scheduleDue()
    }

    private func scheduleDue() {
        let now = ContinuousClock.now
        for key in members where jobs[key] == nil && (nextLookup[key].map { $0 <= now } ?? true) {
            let token = generation
            let lan = network
            jobs[key] = Task {
                let answer = await Self.resolve(key, network: lan)
                guard !Task.isCancelled, generation == token, members.contains(key) else { return }
                jobs[key] = nil
                let old = resolved[key]
                if let answer {
                    resolved[key] = answer
                    nextLookup[key] = ContinuousClock.now.advanced(by: .seconds(30))
                    publish(answer.addresses.union(old?.addresses ?? []))
                } else {
                    nextLookup[key] = ContinuousClock.now.advanced(by: .seconds(5))
                    // A transient resolution failure gets a retry; stale addresses expire.
                    if let old, Date().timeIntervalSince(old.advertisement.observedAt) >= 45 {
                        resolved[key] = nil
                        publish(old.addresses)
                    }
                }
            }
        }
    }

    private nonisolated static func resolve(_ service: Service, network: NetworkSnapshot) async -> Resolution? {
        guard network.interfaceIndex != 0 else { return nil }
        return await NetworkWorkers.bonjour.run { flag in
            var host = [CChar](repeating: 0, count: 1025)
            var addresses = [UInt32](repeating: 0, count: 16)
            var port: UInt16 = 0
            let count = lan_resolve_service(service.name, service.type, service.domain, network.interfaceIndex,
                                            &host, 1025, &port, &addresses, 16, flag)
            let peers = Set(addresses.prefix(count).filter(network.isPeer))
            guard !peers.isEmpty, port != 0 else { return nil }
            let hostname = String(cString: host).trimmingCharacters(in: CharacterSet(charactersIn: "."))
            let record = Advertisement(hostname: hostname, instance: service.name, type: service.type,
                                       port: port, observedAt: Date())
            return Resolution(addresses: peers, advertisement: record)
        }
    }

    private func publish(_ addresses: Set<UInt32>) {
        for address in addresses {
            let records = resolved.values.filter { $0.addresses.contains(address) }
                .map(\.advertisement).sorted { $0.label < $1.label }
            changed?(address, records)
        }
    }

    private func closeBrowsers() {
        browsing = false
        refreshTask?.cancel()
        refreshTask = nil
        for browser in browsers {
            browser.stateUpdateHandler = nil
            browser.browseResultsChangedHandler = nil
            browser.cancel()
        }
        browsers.removeAll()
    }

    // Freeze membership at the end of a single sweep and finish its outstanding resolutions.
    func finish() async {
        closeBrowsers()
        for job in Array(jobs.values) { await job.value }
    }

    func stop() {
        generation = UUID()
        closeBrowsers()
        for job in jobs.values { job.cancel() }
        jobs.removeAll()
        members.removeAll()
        resolved.removeAll()
        nextLookup.removeAll()
        changed = nil
    }
}

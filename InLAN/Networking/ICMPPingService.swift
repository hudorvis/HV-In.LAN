import Foundation

struct HostObservation: Sendable {
    let latency: Double?
    let sentEcho: Bool
    let port: UInt16?
    let tcpChecked: Bool
    let refused: Bool
    let denied: Bool
    let localError: Bool

    var hasReply: Bool { latency != nil || port != nil || refused }
}

private final class ProbeCancellation: @unchecked Sendable {
    let pointer: OpaquePointer
    init?() {
        guard let pointer = lan_cancel_create() else { return nil }
        self.pointer = pointer
    }
    deinit { lan_cancel_destroy(pointer) }
}

// Blocking POSIX and DNS-SD calls stay off both the UI thread and the Swift cooperative pool.
final class NetworkWorkers: @unchecked Sendable {
    static let hosts = NetworkWorkers(limit: 18)
    static let bonjour = NetworkWorkers(limit: 6)
    static let names = NetworkWorkers(limit: 4)
    private let queue = OperationQueue()

    private init(limit: Int) {
        queue.maxConcurrentOperationCount = limit
        queue.qualityOfService = .utility
    }

    func run<T: Sendable>(_ work: @escaping @Sendable (OpaquePointer) -> T?) async -> T? {
        guard !Task.isCancelled, let flag = ProbeCancellation() else { return nil }
        return await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                queue.addOperation {
                    let result: T? = lan_cancelled(flag.pointer) ? nil : work(flag.pointer)
                    continuation.resume(returning: lan_cancelled(flag.pointer) ? nil : result)
                }
            }
        } onCancel: {
            lan_cancel_set(flag.pointer)
        }
    }
}

enum ICMPPingService {
    static func probe(_ address: UInt32, on network: NetworkSnapshot, preferredPort: UInt16?) async -> HostObservation? {
        guard let local = network.subnet?.local, network.isPeer(address) else { return nil }
        return await NetworkWorkers.hosts.run { flag in
            let result = lan_probe(address, local, network.interfaceIndex, preferredPort ?? 0, flag)
            return HostObservation(latency: result.echo_ms >= 0 ? result.echo_ms : nil,
                                   sentEcho: result.echo_sent, port: result.open_port == 0 ? nil : result.open_port,
                                   tcpChecked: result.tcp_checked, refused: result.tcp_refused, denied: result.access_denied,
                                   localError: result.local_error)
        }
    }
}

import Foundation
import Darwin

struct LocalNetworkInfo {
    static func currentSnapshot(interfaces: [String] = []) -> NetworkSnapshot {
        var pointer: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&pointer) == 0, let first = pointer else {
            return .unavailable
        }
        defer { freeifaddrs(pointer) }

        var candidates: [String: NetworkSnapshot] = [:]
        var cursor: UnsafeMutablePointer<ifaddrs>? = first

        while let interface = cursor?.pointee {
            defer { cursor = interface.ifa_next }

            guard let address = interface.ifa_addr,
                  address.pointee.sa_family == UInt8(AF_INET) else { continue }

            let flags = Int32(bitPattern: interface.ifa_flags)
            let isUp = (flags & IFF_UP) != 0
            let isRunning = (flags & IFF_RUNNING) != 0
            let isLoopback = (flags & IFF_LOOPBACK) != 0
            guard isUp, isRunning, !isLoopback else { continue }

            let interfaceName = String(cString: interface.ifa_name)
            let physical = interfaces.contains(interfaceName) ||
                (interfaces.isEmpty && interfaceName.hasPrefix("en") &&
                 interfaceName.dropFirst(2).allSatisfy { $0.isNumber })
            guard physical,
                  let ip = numericHost(from: address),
                  let maskAddress = interface.ifa_netmask,
                  let mask = numericHost(from: maskAddress) else { continue }

            let index = if_nametoindex(interface.ifa_name)
            guard index != 0, let subnet = IPv4Subnet(address: ip, netmask: mask) else { continue }
            let snapshot = NetworkSnapshot(interfaceName: interfaceName, interfaceIndex: index, subnet: subnet)
            candidates[interfaceName] = snapshot
        }

        let order = interfaces.isEmpty ? candidates.keys.sorted() : interfaces
        return order.compactMap { candidates[$0] }.first ?? .unavailable
    }

    private static func numericHost(from address: UnsafePointer<sockaddr>) -> String? {
        var host = [CChar](repeating: 0, count: Int(NI_MAXHOST))
        let length: socklen_t
        switch Int32(address.pointee.sa_family) {
        case AF_INET:
            length = socklen_t(MemoryLayout<sockaddr_in>.size)
        case AF_INET6:
            length = socklen_t(MemoryLayout<sockaddr_in6>.size)
        default:
            return nil
        }

        guard getnameinfo(
            address,
            length,
            &host,
            socklen_t(NI_MAXHOST),
            nil,
            0,
            NI_NUMERICHOST
        ) == 0 else { return nil }
        return String(cString: host)
    }
}

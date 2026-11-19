import Foundation

enum ReverseDNSResolver {
    static func resolve(_ address: UInt32, on interface: UInt32) async -> String? {
        await NetworkWorkers.names.run { flag in
            var buffer = [CChar](repeating: 0, count: 1025)
            let capacity = buffer.count
            guard lan_reverse_name(address, interface, &buffer, capacity, flag) else { return nil }
            return String(validatingUTF8: buffer)
        }
    }
}

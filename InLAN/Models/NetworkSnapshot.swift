import Foundation

enum IPv4 {
    static func value(_ text: String) -> UInt32? {
        let parts = text.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count == 4 else { return nil }
        var result: UInt32 = 0
        for part in parts {
            guard (1...3).contains(part.count), part.utf8.allSatisfy({ (48...57).contains($0) }),
                  let octet = UInt8(part) else { return nil }
            result = (result << 8) | UInt32(octet)
        }
        return result
    }

    static func string(_ ip: UInt32) -> String {
        "\(ip >> 24).\((ip >> 16) & 255).\((ip >> 8) & 255).\(ip & 255)"
    }
}

struct IPv4Subnet: Equatable, Sendable {
    let local: UInt32
    let mask: UInt32

    init?(address: String, netmask: String) {
        guard let local = IPv4.value(address), let mask = IPv4.value(netmask) else { return nil }
        let hostBits = ~mask
        // A valid mask has one contiguous run of host bits, including /31 and /32.
        guard hostBits & (hostBits &+ 1) == 0 else { return nil }
        self.local = local
        self.mask = mask
    }

    var prefixLength: Int { mask.nonzeroBitCount }
    var network: UInt32 { local & mask }
    var broadcast: UInt32 { network | ~mask }

    func isPeer(_ ip: UInt32) -> Bool {
        guard ip != local, ip & mask == network else { return false }
        return prefixLength >= 31 || (ip != network && ip != broadcast)
    }

    func targets(mode: ScanRangeMode, start: String, end: String) throws -> [UInt32] {
        let range: ClosedRange<UInt32>
        switch mode {
        case .automatic, .quick24:
            // The /24 selects a window. Only the physical subnet determines reserved addresses.
            let quickMask = max(mask, 0xFFFFFF00)
            let first = local & quickMask
            range = first...(first | ~quickMask)
        case .fullSubnet:
            guard prefixLength >= 16 else { throw RangeError.tooLarge }
            range = network...broadcast
        case .custom:
            guard let first = IPv4.value(start.trimmingCharacters(in: .whitespacesAndNewlines)),
                  let last = IPv4.value(end.trimmingCharacters(in: .whitespacesAndNewlines)),
                  first <= last, last - first < 4094,
                  (first == local || isPeer(first)), (last == local || isPeer(last)) else {
                throw RangeError.invalid
            }
            range = first...last
        }
        return range.filter(isPeer)
    }

    enum RangeError: Error { case tooLarge, invalid }
}

struct NetworkSnapshot: Equatable, Sendable {
    let interfaceName: String
    // Capture the index alongside the address. A disappeared interface must never become
    // DNSService's index 0 ("any interface") while an outstanding lookup is running.
    let interfaceIndex: UInt32
    let subnet: IPv4Subnet?

    static let unavailable = NetworkSnapshot(interfaceName: "Unavailable", interfaceIndex: 0, subnet: nil)

    var address: String { subnet.map { IPv4.string($0.local) } ?? "—" }
    var netmask: String { subnet.map { IPv4.string($0.mask) } ?? "—" }
    var displayRange: String {
        subnet.map { "\(IPv4.string($0.network))/\($0.prefixLength)" } ?? "No active LAN"
    }

    func isPeer(_ ip: UInt32) -> Bool { subnet?.isPeer(ip) == true && interfaceIndex != 0 }
}

import Foundation

enum PrimaryMode: String, CaseIterable, Identifiable {
    case devices = "Devices"
    case monitor = "Monitor"

    var id: String { rawValue }
}

enum DeviceFilter: String, CaseIterable, Identifiable {
    case all = "All"
    case online = "Online"
    case saved = "Saved"

    var id: String { rawValue }
}

enum ScanRunMode: String, Codable {
    case once
    case continuous
}

enum ScanRangeMode: String, CaseIterable, Identifiable, Codable {
    case automatic = "Automatic"
    case quick24 = "Quick /24"
    case fullSubnet = "Full Subnet"
    case custom = "Custom Range"

    var id: String { rawValue }
}

import Foundation

enum DeviceClassifier {
    static func classify(name: String?, openPorts: [UInt16]) -> DeviceKind {
        let value = (name ?? "").lowercased()
        if value.contains("router") || value.contains("gateway") { return .router }
        if value.contains("macbook") || value.contains("laptop") { return .laptop }
        if value.contains("atem") || value.contains("switcher") { return .switcher }
        if value.contains("camera") || value.contains("ccu") { return .camera }
        if value.contains("nas") || value.contains("server") { return .server }
        if value.contains("audio") || value.contains("console") { return .audio }
        if value.contains("printer") || openPorts.contains(9100) { return .printer }
        if value.contains("encoder") || value.contains("stream") { return .encoder }
        if value.contains("imac") || value.contains("pc") || value.contains("desktop") { return .desktop }
        if openPorts.contains(445) { return .server }
        if openPorts.contains(554) { return .camera }
        return .unknown
    }
}

import Foundation

var device = LANDevice(ipAddress: "192.168.1.10", customName: "Switcher", isSaved: true)
device.record(milliseconds: 4)
device.record(milliseconds: nil, tcpReply: true)
precondition(device.state == .onlineNoPing && device.packetLoss == 50 && device.currentLatencyMS == nil)
device.record(milliseconds: nil, tcpReply: true, echoSent: false)
precondition(device.samples.count == 2 && device.packetLoss == 50)
device.record(milliseconds: nil)
precondition(device.state == .offline)
for _ in 0..<60 { device.record(milliseconds: 40) }
precondition(device.samples.count == 60 && device.minLatencyMS == 40 && device.averageLatencyMS == 40)
precondition(device.packetLoss == 0 && device.statusText == "High latency")
let data = try JSONEncoder().encode(device)
let restored = try JSONDecoder().decode(LANDevice.self, from: data)
precondition(restored.customName == "Switcher" && restored.isSaved)
print("Device state, loss, history and persistence checks passed.")

let observed = Date(timeIntervalSinceReferenceDate: 100)
let checked = observed.addingTimeInterval(8)
var advertised = LANDevice(ipAddress: "192.168.1.20")
advertised.observeService(at: observed)
advertised.record(milliseconds: nil, serviceSeenAt: observed, echoSent: false, now: checked)
precondition(advertised.state == .onlineNoPing && advertised.lastSeen == observed)
precondition(advertised.samples.isEmpty && advertised.lossText == "—")
advertised.record(milliseconds: 3, now: checked)
advertised.observeService(at: observed)
precondition(advertised.state == .online && advertised.currentLatencyMS == 3 && advertised.lastSeen == checked)
advertised.record(milliseconds: nil, echoSent: false, tcpChecked: true)
precondition(advertised.state == .offline && advertised.samples.count == 1)
print("Bonjour observation time and TCP-only reachability checks passed.")

let subnet = IPv4Subnet(address: "192.168.1.10", netmask: "255.255.254.0")!
let quick = try subnet.targets(mode: .quick24, start: "", end: "").map(IPv4.string)
precondition(quick.count == 254 && quick.first == "192.168.1.0" && quick.last == "192.168.1.254")
precondition(!quick.contains("192.168.1.10"))
let full = try subnet.targets(mode: .fullSubnet, start: "", end: "")
precondition(full.count == 509)
let pointToPoint = IPv4Subnet(address: "192.0.2.0", netmask: "255.255.255.254")!
let peer = try pointToPoint.targets(mode: .automatic, start: "", end: "")
precondition(peer.map(IPv4.string) == ["192.0.2.1"])
let single = IPv4Subnet(address: "192.0.2.1", netmask: "255.255.255.255")!
let singleTargets = try single.targets(mode: .automatic, start: "", end: "")
precondition(singleTargets.isEmpty)
let wide = IPv4Subnet(address: "10.0.0.1", netmask: "255.0.0.0")!
do {
    _ = try wide.targets(mode: .fullSubnet, start: "", end: "")
    preconditionFailure("Full Subnet admitted a /8")
} catch IPv4Subnet.RangeError.tooLarge {}
let custom = try wide.targets(mode: .custom, start: "10.0.1.1", end: "10.0.16.254")
precondition(custom.count == 4094)
for end in ["10.0.16.255", "11.0.1.1", "10.0.1.-1", "10.0.1.999"] {
    do {
        _ = try wide.targets(mode: .custom, start: "10.0.1.1", end: end)
        preconditionFailure("Accepted invalid custom range ending in \(end)")
    } catch IPv4Subnet.RangeError.invalid {}
}
precondition(IPv4Subnet(address: "10.0.0.1", netmask: "255.0.255.0") == nil)
print("Subnet, point-to-point and custom range checks passed.")

@MainActor
func checkStore() throws {
    let suite = "InLAN.tests." + UUID().uuidString
    let defaults = UserDefaults(suiteName: suite)!
    defer { defaults.removePersistentDomain(forName: suite) }
    let store = DeviceStore(defaults: defaults)
    let saved = LANDevice(ipAddress: "192.0.2.2", isSaved: true)
    let named = LANDevice(ipAddress: "192.0.2.3", customName: "Switcher")
    let transient = LANDevice(ipAddress: "192.0.2.4")
    store.save([saved, named, transient])
    precondition(store.load() == [saved, named])

    let key = "inlan.saved-devices.v1"
    let records = try JSONSerialization.jsonObject(with: defaults.data(forKey: key)!) as! [[String: Any]]
    let mixed = try JSONSerialization.data(withJSONObject: records + [["ipAddress": "invalid record"]])
    defaults.set(mixed, forKey: key)
    precondition(store.load() == [saved, named])
    store.save(store.load())
    precondition(defaults.data(forKey: key + ".recovery") == mixed)
    precondition(store.load() == [saved, named])
}
try MainActor.assumeIsolated { try checkStore() }
print("Saved, renamed and partially damaged device list checks passed.")

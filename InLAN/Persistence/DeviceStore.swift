import Foundation

@MainActor
final class DeviceStore {
    private static let key = "inlan.saved-devices.v1"
    private let defaults: UserDefaults?

    init(defaults: UserDefaults? = .standard) {
        self.defaults = defaults
    }

    func load() -> [LANDevice] {
        guard let defaults, let data = defaults.data(forKey: Self.key) else { return [] }
        let decoder = JSONDecoder()
        if let devices = try? decoder.decode([LANDevice].self, from: data) { return devices }

        // A single unreadable record must not erase every other favourite on the next save.
        let recoveryKey = Self.key + ".recovery"
        if defaults.data(forKey: recoveryKey) == nil { defaults.set(data, forKey: recoveryKey) }
        guard let object = try? JSONSerialization.jsonObject(with: data), let rows = object as? [Any] else { return [] }
        return rows.compactMap { row in
            guard let record = row as? [String: Any], let bytes = try? JSONSerialization.data(withJSONObject: record) else { return nil }
            return try? decoder.decode(LANDevice.self, from: bytes)
        }
    }

    func save(_ devices: [LANDevice]) {
        guard let defaults else { return }
        let persistent = devices.filter { $0.isSaved || $0.customName != nil }
        guard let data = try? JSONEncoder().encode(persistent) else { return }
        defaults.set(data, forKey: Self.key)
    }
}

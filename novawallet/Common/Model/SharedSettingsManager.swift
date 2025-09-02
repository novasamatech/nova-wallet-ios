import Keystore_iOS

enum SharedSettingsKey: String, CaseIterable {
    case selectedLocalization
    case selectedCurrency
}

final class SharedSettingsManager: SettingsManagerProtocol {
    private let userDefaults: UserDefaults

    init?(group: String = SharedContainerGroup.name) {
        if let userDefaults = UserDefaults(suiteName: group) {
            self.userDefaults = userDefaults
        } else {
            return nil
        }
    }

    func set(value: Bool, for key: String) {
        userDefaults.set(value, forKey: key)
        userDefaults.synchronize()
    }

    func set(value: Int, for key: String) {
        userDefaults.set(value, forKey: key)
        userDefaults.synchronize()
    }

    func set(value: Double, for key: String) {
        userDefaults.set(value, forKey: key)
        userDefaults.synchronize()
    }

    func set(value: String, for key: String) {
        userDefaults.setValue(value, forKey: key)
        userDefaults.synchronize()
    }

    func set(value: Data, for key: String) {
        userDefaults.setValue(value, forKey: key)
        userDefaults.synchronize()
    }

    func set(anyValue: Any, for key: String) {
        userDefaults.setValue(anyValue, forKey: key)
        userDefaults.synchronize()
    }

    func bool(for key: String) -> Bool? {
        guard userDefaults.object(forKey: key) != nil else {
            return nil
        }

        return userDefaults.bool(forKey: key)
    }

    func integer(for key: String) -> Int? {
        guard userDefaults.object(forKey: key) != nil else {
            return nil
        }

        return userDefaults.integer(forKey: key)
    }

    func double(for key: String) -> Double? {
        guard userDefaults.object(forKey: key) != nil else {
            return nil
        }

        return userDefaults.double(forKey: key)
    }

    func string(for key: String) -> String? {
        userDefaults.value(forKey: key) as? String
    }

    func data(for key: String) -> Data? {
        userDefaults.value(forKey: key) as? Data
    }

    func anyValue(for key: String) -> Any? {
        userDefaults.value(forKey: key)
    }

    func removeValue(for key: String) {
        userDefaults.removeObject(forKey: key)
        userDefaults.synchronize()
    }

    func removeAll() {
        if let domain = Bundle.main.bundleIdentifier {
            userDefaults.removePersistentDomain(forName: domain)
        }
    }
}

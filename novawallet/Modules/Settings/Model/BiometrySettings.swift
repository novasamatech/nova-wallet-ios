import Keystore_iOS

enum BiometrySettings {
    case notAvailable
    case faceId(isEnabled: Bool)
    case touchId(isEnabled: Bool)

    var isEnabled: Bool? {
        switch self {
        case .notAvailable:
            return nil
        case let .faceId(isEnabled):
            return isEnabled
        case let .touchId(isEnabled):
            return isEnabled
        }
    }

    static func create(
        from type: AvailableBiometryType,
        settingsManager: SettingsManagerProtocol
    ) -> BiometrySettings {
        let biometryEnabled = settingsManager.biometryEnabled ?? false

        switch type {
        case .faceId:
            return .faceId(isEnabled: biometryEnabled)
        case .touchId:
            return .touchId(isEnabled: biometryEnabled)
        case .none:
            return .notAvailable
        }
    }

    var name: String {
        switch self {
        case .notAvailable:
            return ""
        case .faceId:
            return "Face ID"
        case .touchId:
            return "Touch ID"
        }
    }
}

import Foundation

struct PrivacyModeSettings: Codable {
    let privacySettingsEnabled: Bool
    let lastEnabled: Bool

    var enabled: Bool {
        privacySettingsEnabled ? privacySettingsEnabled : lastEnabled
    }

    func with(lastEnabled: Bool) -> Self {
        .init(
            privacySettingsEnabled: privacySettingsEnabled,
            lastEnabled: lastEnabled
        )
    }

    func with(privacySettingsEnabled: Bool) -> Self {
        .init(
            privacySettingsEnabled: privacySettingsEnabled,
            lastEnabled: lastEnabled
        )
    }
}

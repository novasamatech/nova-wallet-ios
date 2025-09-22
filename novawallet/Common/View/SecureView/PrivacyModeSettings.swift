import Foundation

struct PrivacyModeSettings: Codable {
    let enablePrivacyModeOnLaunch: Bool
    let privacyModeEnabled: Bool

    func with(privacyModeEnabled: Bool) -> Self {
        .init(
            enablePrivacyModeOnLaunch: enablePrivacyModeOnLaunch,
            privacyModeEnabled: privacyModeEnabled
        )
    }

    func with(enablePrivacyModeOnLaunch: Bool) -> Self {
        .init(
            enablePrivacyModeOnLaunch: enablePrivacyModeOnLaunch,
            privacyModeEnabled: privacyModeEnabled
        )
    }
}

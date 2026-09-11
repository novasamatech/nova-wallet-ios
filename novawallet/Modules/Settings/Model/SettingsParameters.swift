import Foundation

struct SettingsParameters {
    let walletConnectSessionsCount: Int?
    let isBiometricAuthOn: Bool?
    let isPinConfirmationOn: Bool
    let isNotificationsOn: Bool
    let isHideBalancesOn: Bool
    /// `nil` hides the row, and only when the subsystem is unavailable *and* stored consent is
    /// off. Consent left on by a remote kill switch keeps the row: it is the only way to withdraw.
    let isAnalyticsOn: Bool?
}

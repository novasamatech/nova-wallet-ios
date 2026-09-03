import Foundation

struct SettingsParameters {
    let walletConnectSessionsCount: Int?
    let isBiometricAuthOn: Bool?
    let isPinConfirmationOn: Bool
    let isNotificationsOn: Bool
    let isHideBalancesOn: Bool
    /// `nil` hides the row entirely: an unattestable device or a remote-disabled build
    /// must not offer a switch the user could not act on.
    let isAnalyticsOn: Bool?
}

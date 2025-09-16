import Foundation
import UIKit

enum NotificationsManagementSection {
    case main(warning: String?)
    case general
    case balances
    case others

    func title(for locale: Locale) -> String? {
        switch self {
        case .main:
            return nil
        case .general:
            return R.string(preferredLanguages: locale.rLanguages).localizable.settingsGeneral().uppercased()
        case .balances:
            return R.string(
                preferredLanguages: locale.rLanguages
            ).localizable.notificationsManagementBalances().uppercased()
        case .others:
            return R.string(
                preferredLanguages: locale.rLanguages
            ).localizable.notificationsManagementOthers().uppercased()
        }
    }
}

enum NotificationsManagementRow {
    case enableNotifications
    case wallets
    case announcements
    case sentTokens
    case receivedTokens
    case gov
    case staking
    case multisig

    var icon: UIImage? {
        switch self {
        case .enableNotifications:
            return R.image.iconNotification()
        case .wallets:
            return R.image.iconWallets()
        case .announcements, .sentTokens, .receivedTokens, .gov, .staking, .multisig:
            return nil
        }
    }

    func title(for locale: Locale) -> String {
        switch self {
        case .enableNotifications:
            return R.string(
                preferredLanguages: locale.rLanguages
            ).localizable.notificationsManagementEnableNotifications()
        case .wallets:
            return R.string(preferredLanguages: locale.rLanguages).localizable.notificationsManagementWallets()
        case .announcements:
            return R.string(preferredLanguages: locale.rLanguages).localizable.notificationsManagementAnnouncements()
        case .sentTokens:
            return R.string(preferredLanguages: locale.rLanguages).localizable.notificationsManagementSentTokens()
        case .receivedTokens:
            return R.string(preferredLanguages: locale.rLanguages).localizable.notificationsManagementReceivedTokens()
        case .gov:
            return R.string(preferredLanguages: locale.rLanguages).localizable.tabbarGovernanceTitle()
        case .staking:
            return R.string(preferredLanguages: locale.rLanguages).localizable.notificationsManagementStakingRewards()
        case .multisig:
            return R.string(
                preferredLanguages: locale.rLanguages
            ).localizable.notificationsManagementMultisigTransactions()
        }
    }
}

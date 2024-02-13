import Foundation
import UIKit

enum NotificationsManagementSection {
    case main
    case general
    case balances
    case others

    func title(for locale: Locale) -> String? {
        switch self {
        case .main:
            return nil
        case .general:
            return R.string.localizable.notificationsManagementGeneral(
                preferredLanguages: locale.rLanguages
            ).uppercased()
        case .balances:
            return R.string.localizable.notificationsManagementBalances(
                preferredLanguages: locale.rLanguages
            ).uppercased()
        case .others:
            return R.string.localizable.notificationsManagementOthers(
                preferredLanguages: locale.rLanguages
            ).uppercased()
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

    var icon: UIImage? {
        switch self {
        case .enableNotifications:
            return R.image.iconNotiifcation()
        case .wallets:
            return R.image.iconWallets()
        case .announcements, .sentTokens, .receivedTokens, .gov, .staking:
            return nil
        }
    }

    func title(for locale: Locale) -> String {
        switch self {
        case .enableNotifications:
            return R.string.localizable.notificationsManagementEnableNotifications(
                preferredLanguages: locale.rLanguages
            )
        case .wallets:
            return R.string.localizable.notificationsManagementWallets(
                preferredLanguages: locale.rLanguages
            )
        case .announcements:
            return R.string.localizable.notificationsManagementAnnouncements(
                preferredLanguages: locale.rLanguages
            )
        case .sentTokens:
            return R.string.localizable.notificationsManagementSentTokens(
                preferredLanguages: locale.rLanguages
            )
        case .receivedTokens:
            return R.string.localizable.notificationsManagementReceivedTokens(
                preferredLanguages: locale.rLanguages
            )
        case .gov:
            return R.string.localizable.notificationsManagementGov(
                preferredLanguages: locale.rLanguages
            )
        case .staking:
            return R.string.localizable.notificationsManagementStakingRewards(
                preferredLanguages: locale.rLanguages
            )
        }
    }
}

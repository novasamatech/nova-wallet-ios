import Foundation_iOS

struct NotificationsManagementParameters {
    let isNotificationsOn: Bool
    let wallets: Int
    let isAnnouncementsOn: Bool
    let isSentTokensOn: Bool
    let isReceiveTokensOn: Bool
    let isMultisigTransactionsOn: Bool
    let isGovernanceOn: Bool
    let isStakingOn: Bool

    var walletDependentNotificationsOn: Bool {
        isSentTokensOn || isReceiveTokensOn || isStakingOn
    }
}

protocol NotificationsManagemenViewModelFactoryProtocol {
    func createSectionViewModels(
        parameters: NotificationsManagementParameters,
        locale: Locale
    ) -> [(NotificationsManagementSection, [NotificationsManagementCellModel])]
}

final class NotificationsManagemenViewModelFactory: NotificationsManagemenViewModelFactoryProtocol {
    let quantityFormatter: LocalizableResource<NumberFormatter>

    init(
        quantityFormatter: LocalizableResource<NumberFormatter>
    ) {
        self.quantityFormatter = quantityFormatter
    }

    func createSectionViewModels(
        parameters: NotificationsManagementParameters,
        locale: Locale
    ) -> [(NotificationsManagementSection, [NotificationsManagementCellModel])] {
        let warning = warning(parameters: parameters, locale: locale)

        return [
            (.main(warning: warning), [
                createSwitchViewModel(row: .enableNotifications, isOn: parameters.isNotificationsOn, isActive: true, locale: locale),
                createViewModel(row: .wallets, count: parameters.wallets, isActive: true, locale: locale)
            ]),
            (.general, [
                createSwitchViewModel(
                    row: .announcements,
                    isOn: parameters.isAnnouncementsOn,
                    isActive: parameters.isNotificationsOn,
                    locale: locale
                )
            ]),
            (.balances, [
                createSwitchViewModel(
                    row: .sentTokens,
                    isOn: parameters.isSentTokensOn,
                    isActive: parameters.isNotificationsOn,
                    locale: locale
                ),
                createSwitchViewModel(
                    row: .receivedTokens,
                    isOn: parameters.isReceiveTokensOn,
                    isActive: parameters.isNotificationsOn,
                    locale: locale
                )
            ]),
            (.others, [
                createAccessoryViewModel(
                    row: .multisig,
                    isOn: parameters.isMultisigTransactionsOn,
                    isActive: parameters.isNotificationsOn,
                    locale: locale
                ),
                createAccessoryViewModel(
                    row: .gov,
                    isOn: parameters.isGovernanceOn,
                    isActive: parameters.isNotificationsOn,
                    locale: locale
                ),
                createAccessoryViewModel(
                    row: .staking,
                    isOn: parameters.isStakingOn,
                    isActive: parameters.isNotificationsOn,
                    locale: locale
                )
            ])
        ]
    }

    private func warning(
        parameters: NotificationsManagementParameters,
        locale: Locale
    ) -> String? {
        guard parameters.wallets == 0, parameters.walletDependentNotificationsOn else {
            return nil
        }

        return R.string.localizable.notificationsManagementWalletsWarning(
            preferredLanguages: locale.rLanguages
        )
    }

    private func createSwitchViewModel(
        row: NotificationsManagementRow,
        isOn: Bool,
        isActive: Bool,
        locale: Locale
    ) -> NotificationsManagementCellModel {
        .init(
            row: row,
            title: .init(
                title: row.title(for: locale),
                icon: row.icon
            ),
            accessory: .switchControl(isOn: isOn),
            isActive: isActive
        )
    }

    private func createAccessoryViewModel(
        row: NotificationsManagementRow,
        isOn: Bool,
        isActive: Bool,
        locale: Locale
    ) -> NotificationsManagementCellModel {
        let accessory = isOn ? R.string.localizable.commonOn(preferredLanguages: locale.rLanguages) :
            R.string.localizable.commonOff(preferredLanguages: locale.rLanguages)

        return .init(
            row: row,
            title: .init(
                title: row.title(for: locale),
                icon: row.icon
            ),
            accessory: .init(optTitle: accessory),
            isActive: isActive
        )
    }

    private func createViewModel(
        row: NotificationsManagementRow,
        count: Int,
        isActive: Bool,
        locale: Locale
    ) -> NotificationsManagementCellModel {
        let count = quantityFormatter.value(for: locale).string(from: .init(value: count)) ?? ""

        return .init(
            row: row,
            title: .init(
                title: row.title(for: locale),
                icon: row.icon
            ),
            accessory: .init(optTitle: count),
            isActive: isActive
        )
    }
}

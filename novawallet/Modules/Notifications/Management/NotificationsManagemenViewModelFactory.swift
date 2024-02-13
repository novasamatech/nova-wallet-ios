import SoraFoundation

struct NotificationsManagementParameters {
    let isNotificationsOn: Bool
    let wallets: Int
    let isAnnouncementsOn: Bool
    let isSentTokensOn: Bool
    let isReceiveTokensOn: Bool
    let isGovernanceOn: Bool
    let isStakingOn: Bool
}

protocol NotificationsManagemenViewModelFactoryProtocol {
    func createSectionViewModels(
        parameters: NotificationsManagementParameters,
        locale: Locale
    ) -> [(NotificationsManagementSection, [CommonSettingsCellViewModel<NotificationsManagementRow>])]
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
    ) -> [(NotificationsManagementSection, [CommonSettingsCellViewModel<NotificationsManagementRow>])] {
        [
            (.main, [
                createSwitchViewModel(row: .enableNotifications, isOn: parameters.isNotificationsOn, locale: locale),
                createViewModel(row: .wallets, count: parameters.wallets, locale: locale)
            ]),
            (.general, [
                createSwitchViewModel(row: .announcements, isOn: parameters.isAnnouncementsOn, locale: locale)
            ]),
            (.balances, [
                createSwitchViewModel(row: .sentTokens, isOn: parameters.isSentTokensOn, locale: locale),
                createSwitchViewModel(row: .receivedTokens, isOn: parameters.isReceiveTokensOn, locale: locale)
            ]),
            (.others, [
                createAccessoryViewModel(row: .gov, isOn: parameters.isGovernanceOn, locale: locale),
                createAccessoryViewModel(row: .staking, isOn: parameters.isStakingOn, locale: locale)
            ])
        ]
    }

    private func createSwitchViewModel(
        row: NotificationsManagementRow,
        isOn: Bool,
        locale: Locale
    ) -> CommonSettingsCellViewModel<NotificationsManagementRow> {
        .init(
            row: row,
            title: .init(
                title: row.title(for: locale),
                icon: row.icon
            ),
            accessory: .switchControl(isOn: isOn)
        )
    }

    private func createAccessoryViewModel(
        row: NotificationsManagementRow,
        isOn: Bool,
        locale: Locale
    ) -> CommonSettingsCellViewModel<NotificationsManagementRow> {
        let accessory = isOn ? R.string.localizable.commonOn(preferredLanguages: locale.rLanguages) :
            R.string.localizable.commonOff(preferredLanguages: locale.rLanguages)

        return .init(
            row: row,
            title: .init(
                title: row.title(for: locale),
                icon: row.icon
            ),
            accessory: .init(optTitle: accessory)
        )
    }

    private func createViewModel(
        row: NotificationsManagementRow,
        count: Int,
        locale: Locale
    ) -> CommonSettingsCellViewModel<NotificationsManagementRow> {
        let count = quantityFormatter.value(for: locale).string(from: .init(value: count)) ?? ""

        return .init(
            row: row,
            title: .init(
                title: row.title(for: locale),
                icon: row.icon
            ),
            accessory: .init(optTitle: count)
        )
    }
}

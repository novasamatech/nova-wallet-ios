import Foundation
import SoraFoundation
import SubstrateSdk
import IrohaCrypto

final class SettingsViewModelFactory: SettingsViewModelFactoryProtocol {
    let iconGenerator: IconGenerating
    let quantityFormatter: LocalizableResource<NumberFormatter>

    init(
        iconGenerator: IconGenerating,
        quantityFormatter: LocalizableResource<NumberFormatter>
    ) {
        self.iconGenerator = iconGenerator
        self.quantityFormatter = quantityFormatter
    }

    func createAccountViewModel(for wallet: MetaAccountModel) -> SettingsAccountViewModel {
        let icon = wallet.walletIdenticonData().flatMap { try? iconGenerator.generateFromAccountId($0) }?
            .imageWithFillColor(
                .clear,
                size: UIConstants.normalAddressIconSize,
                contentScale: UIScreen.main.scale
            )

        return SettingsAccountViewModel(
            name: wallet.name,
            icon: icon,
            walletType: WalletsListSectionViewModel.SectionType(walletType: wallet.type)
        )
    }

    func createSectionViewModels(
        language: Language?,
        currency: String?,
        parameters: SettingsParameters,
        locale: Locale
    ) -> [(SettingsSection, [SettingsCellViewModel])] {
        [
            (.general, [
                createCommonViewViewModel(row: .wallets, locale: locale),
                createWalletConnectViewModel(from: parameters.walletConnectSessionsCount, locale: locale)
            ]),
            (.preferences, [
                createValuableViewModel(row: .currency, value: currency, locale: locale),
                createLanguageViewModel(from: language, locale: locale)
            ]),
            (.security, [
                parameters.isBiometricAuthOn.map {
                    createSwitchViewModel(row: .biometricAuth, isOn: $0, locale: locale)
                },
                createSwitchViewModel(
                    row: .approveWithPin,
                    isOn: parameters.isPinConfirmationOn,
                    locale: locale
                ),
                createCommonViewViewModel(row: .changePin, locale: locale)
            ].compactMap { $0 }),
            (.community, [
                createCommonViewViewModel(row: .telegram, locale: locale),
                createCommonViewViewModel(row: .twitter, locale: locale),
                createCommonViewViewModel(row: .youtube, locale: locale)
            ]),
            (.support, [
                createCommonViewViewModel(row: .rateUs, locale: locale),
                createCommonViewViewModel(row: .email, locale: locale)
            ]),
            (.about, [
                createCommonViewViewModel(row: .website, locale: locale),
                createCommonViewViewModel(row: .github, locale: locale),
                createCommonViewViewModel(row: .terms, locale: locale),
                createCommonViewViewModel(row: .privacyPolicy, locale: locale)
            ])
        ]
    }

    private func createCommonViewViewModel(
        row: SettingsRow,
        locale: Locale
    ) -> SettingsCellViewModel {
        SettingsCellViewModel(
            row: row,
            title: .init(title: row.title(for: locale), icon: row.icon),
            accessory: .none
        )
    }

    private func createLanguageViewModel(from language: Language?, locale: Locale) -> SettingsCellViewModel {
        let title = R.string.localizable
            .profileLanguageTitle(preferredLanguages: locale.rLanguages)

        let subtitle = language?.title(in: locale)?.capitalized

        let viewModel = SettingsCellViewModel(
            row: .language,
            title: .init(title: title, icon: SettingsRow.language.icon),
            accessory: .init(optTitle: subtitle)
        )

        return viewModel
    }

    private func createWalletConnectViewModel(
        from counter: Int?,
        locale: Locale
    ) -> SettingsCellViewModel {
        let row = SettingsRow.walletConnect

        let subtitle: String? = counter.flatMap { counter in
            if counter > 0 {
                return quantityFormatter.value(for: locale).string(from: .init(value: counter))
            } else {
                return nil
            }
        }

        return SettingsCellViewModel(
            row: row,
            title: .init(title: row.title(for: locale), icon: row.icon),
            accessory: .init(optTitle: subtitle, icon: R.image.iconConnections())
        )
    }

    private func createValuableViewModel(
        row: SettingsRow,
        value: String?,
        locale: Locale
    ) -> SettingsCellViewModel {
        SettingsCellViewModel(
            row: row,
            title: .init(title: row.title(for: locale), icon: row.icon),
            accessory: .init(optTitle: value)
        )
    }

    private func createSwitchViewModel(
        row: SettingsRow,
        isOn: Bool,
        locale: Locale
    ) -> SettingsCellViewModel {
        SettingsCellViewModel(
            row: row,
            title: .init(title: row.title(for: locale), icon: row.icon),
            accessory: .switchControl(isOn: isOn)
        )
    }
}

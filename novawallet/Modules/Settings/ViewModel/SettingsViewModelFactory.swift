import Foundation
import SoraFoundation
import SubstrateSdk
import IrohaCrypto

final class SettingsViewModelFactory: SettingsViewModelFactoryProtocol {
    let iconGenerator: IconGenerating

    init(iconGenerator: IconGenerating) {
        self.iconGenerator = iconGenerator
    }

    func createAccountViewModel(for wallet: MetaAccountModel) -> SettingsAccountViewModel {
        let icon = try? iconGenerator.generateFromAccountId(wallet.substrateAccountId)
            .imageWithFillColor(
                .clear,
                size: UIConstants.normalAddressIconSize,
                contentScale: UIScreen.main.scale
            )

        return SettingsAccountViewModel(name: wallet.name, icon: icon)
    }

    func createSectionViewModels(
        language: Language?,
        locale: Locale
    ) -> [(SettingsSection, [SettingsCellViewModel])] {
        [
            (.general, [createCommonViewViewModel(row: .wallets, locale: locale)]),
            (.preferences, [createLanguageViewModel(from: language, locale: locale)]),
            (.security, [createCommonViewViewModel(row: .changePin, locale: locale)]),
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
            title: row.title(for: locale),
            icon: row.icon,
            accessoryTitle: nil
        )
    }

    private func createLanguageViewModel(from language: Language?, locale: Locale) -> SettingsCellViewModel {
        let title = R.string.localizable
            .profileLanguageTitle(preferredLanguages: locale.rLanguages)
        let subtitle = language?.title(in: locale)?.capitalized
        let viewModel = SettingsCellViewModel(
            row: .language,
            title: title,
            icon: SettingsRow.language.icon,
            accessoryTitle: subtitle
        )

        return viewModel
    }
}

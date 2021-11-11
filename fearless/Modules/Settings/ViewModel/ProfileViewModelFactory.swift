import Foundation
import SoraFoundation
import SubstrateSdk
import IrohaCrypto

protocol SettingsViewModelFactoryProtocol: AnyObject {
    func createUserViewModel(from settings: UserSettings, locale: Locale) -> ProfileUserViewModelProtocol

    func createSectionViewModels(
        from settings: UserSettings,
        language: Language,
        locale: Locale
    ) -> [(SettingsSection, [SettingsCellViewModel])]
}

enum ProfileOption: UInt, CaseIterable {
    case accountList
    case language
    case changePincode
    case about
    case connectionList
}

final class SettingsViewModelFactory: SettingsViewModelFactoryProtocol {
    let iconGenerator: IconGenerating

    init(iconGenerator: IconGenerating) {
        self.iconGenerator = iconGenerator
    }

    func createUserViewModel(from settings: UserSettings, locale _: Locale) -> ProfileUserViewModelProtocol {
        let icon = try? iconGenerator.generateFromAddress(settings.details)

        return ProfileUserViewModel(
            name: settings.userName,
            details: settings.details,
            icon: icon
        )
    }

    func createSectionViewModels(
        from _: UserSettings,
        language: Language,
        locale: Locale
    ) -> [(SettingsSection, [SettingsCellViewModel])] {
        [
            (.general, [createAccountListViewModel(for: locale)]),
            (.preferences, [createLanguageViewModel(from: language, locale: locale)]),
            (.security, [createChangePincode(for: locale)]),
            (.about, [createAboutViewModel(for: locale)]),
        ]
    }

    private func createAccountListViewModel(for locale: Locale) -> SettingsCellViewModel {
        let title = R.string.localizable
            .profileWalletsTitle(preferredLanguages: locale.rLanguages)
        let viewModel = SettingsCellViewModel(
            title: title,
            icon: R.image.iconProfileAccounts()!,
            accessoryTitle: nil
        )
        return viewModel
    }

    private func createConnectionListViewModel(for locale: Locale) -> SettingsCellViewModel {
        let title = R.string.localizable
            .profileNetworkTitle(preferredLanguages: locale.rLanguages)

        let viewModel = SettingsCellViewModel(
            title: title,
            icon: R.image.iconProfileNetworks()!,
            accessoryTitle: nil
        )

        return viewModel
    }

    private func createChangePincode(for locale: Locale) -> SettingsCellViewModel {
        let title = R.string.localizable
            .profilePincodeChangeTitle(preferredLanguages: locale.rLanguages)
        return SettingsCellViewModel(
            title: title,
            icon: R.image.iconProfilePin()!,
            accessoryTitle: nil
        )
    }

    private func createLanguageViewModel(from language: Language?, locale: Locale) -> SettingsCellViewModel {
        let title = R.string.localizable
            .profileLanguageTitle(preferredLanguages: locale.rLanguages)
        let subtitle = language?.title(in: locale)?.capitalized
        let viewModel = SettingsCellViewModel(
            title: title,
            icon: R.image.iconProfileLanguage()!,
            accessoryTitle: subtitle
        )

        return viewModel
    }

    private func createAboutViewModel(for locale: Locale) -> SettingsCellViewModel {
        let title = R.string.localizable
            .profileAboutTitle(preferredLanguages: locale.rLanguages)
        return SettingsCellViewModel(
            title: title,
            icon: R.image.iconProfileAbout()!,
            accessoryTitle: nil
        )
    }
}

import Foundation

class BaseValidatorInfoViewModelFactory {
    func createLegalRow(with legal: String, locale: Locale) -> ValidatorInfoViewModel.IdentityItem {
        let title = R.string(preferredLanguages: locale.rLanguages).localizable.identityLegalNameTitle()
        return .init(title: title, value: .text(legal))
    }

    func createEmailRow(with email: String, locale: Locale) -> ValidatorInfoViewModel.IdentityItem {
        let title = R.string(preferredLanguages: locale.rLanguages).localizable.identityEmailTitle()
        return .init(title: title, value: .link(email, tag: .email))
    }

    func createWebRow(with web: String, locale: Locale) -> ValidatorInfoViewModel.IdentityItem {
        let title = R.string(preferredLanguages: locale.rLanguages).localizable.identityWebTitle()
        return .init(title: title, value: .link(web, tag: .web))
    }

    func createTwitterRow(with twitter: String) -> ValidatorInfoViewModel.IdentityItem {
        .init(title: "Twitter", value: .link(twitter, tag: .twitter))
    }

    func createRiotRow(with riot: String, locale: Locale) -> ValidatorInfoViewModel.IdentityItem {
        let title = R.string(preferredLanguages: locale.rLanguages).localizable.identityRiotNameTitle()
        return .init(title: title, value: .link(riot, tag: .riot))
    }

    func createIdentityViewModel(
        from identity: AccountIdentity,
        locale: Locale
    ) -> [ValidatorInfoViewModel.IdentityItem] {
        var identityItems: [ValidatorInfoViewModel.IdentityItem] = []

        if let legal = identity.legal {
            identityItems.append(createLegalRow(with: legal, locale: locale))
        }

        if let email = identity.email {
            identityItems.append(createEmailRow(with: email, locale: locale))
        }

        if let web = identity.web {
            identityItems.append(createWebRow(with: web, locale: locale))
        }

        if let twitter = identity.twitter {
            identityItems.append(createTwitterRow(with: twitter))
        }

        if let riot = identity.riot {
            identityItems.append(createRiotRow(with: riot, locale: locale))
        }

        return identityItems
    }
}

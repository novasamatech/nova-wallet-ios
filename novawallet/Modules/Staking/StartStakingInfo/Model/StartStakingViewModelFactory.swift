import Foundation

protocol StartStakingViewModelFactoryProtocol {
    func earnupModel(locale: Locale) -> AccentTextModel
    func stakeModel(locale: Locale) -> ParagraphView.Model
    func unstakeModel(locale: Locale) -> ParagraphView.Model
    func rewardModel(locale: Locale) -> ParagraphView.Model
    func govModel(locale: Locale) -> ParagraphView.Model
    func recommendationModel(locale: Locale) -> ParagraphView.Model
    func testNetworkModel(
        chain: ChainModel,
        locale: Locale
    ) -> ParagraphView.Model
    func wikiModel(locale: Locale, url: URL) -> StartStakingUrlModel
    func termsModel(locale: Locale, url: URL) -> StartStakingUrlModel
    func balance(locale: Locale) -> String
}

struct StartStakingViewModelFactory: StartStakingViewModelFactoryProtocol {
    func earnupModel(locale: Locale) -> AccentTextModel {
        let amount = "22.86%"
        let token = "DOT"
        let value = R.string.localizable.stakingStartEarnUp(amount, preferredLanguages: locale.rLanguages)
        let text = R.string.localizable.stakingStartEarnUpTitle(
            value,
            token,
            preferredLanguages: locale.rLanguages
        )

        let textWithAccents = AccentTextModel(
            text: text,
            accents: [value]
        )
        return textWithAccents
    }

    func stakeModel(locale: Locale) -> ParagraphView.Model {
        let amount = "1 DOT"
        let time = "in 4 hours and 34 minutes"

        let text = R.string.localizable.stakingStartStake(amount, time, preferredLanguages: locale.rLanguages)
        let textWithAccents = AccentTextModel(
            text: text,
            accents: [amount, time]
        )
        return .init(
            image: R.image.coin(),
            text: textWithAccents
        )
    }

    func unstakeModel(locale: Locale) -> ParagraphView.Model {
        let unstakePeriod = "after 28 days"

        let text = R.string.localizable.stakingStartUnstake(unstakePeriod, preferredLanguages: locale.rLanguages)
        let textWithAccents = AccentTextModel(
            text: text,
            accents: [unstakePeriod]
        )
        return .init(
            image: R.image.clock(),
            text: textWithAccents
        )
    }

    func rewardModel(locale: Locale) -> ParagraphView.Model {
        let rewardIntervals = "every 6 hours"
        let text = R.string.localizable.stakingStartRewards(
            rewardIntervals,
            preferredLanguages: locale.rLanguages
        )
        let textWithAccents = AccentTextModel(
            text: text,
            accents: [rewardIntervals]
        )
        return .init(
            image: R.image.cup(),
            text: textWithAccents
        )
    }

    func govModel(locale: Locale) -> ParagraphView.Model {
        let action = R.string.localizable.stakingStartGovAction(preferredLanguages: locale.rLanguages)
        let text = R.string.localizable.stakingStartGov(action, preferredLanguages: locale.rLanguages)
        let textWithAccents = AccentTextModel(
            text: text,
            accents: [action]
        )
        return .init(
            image: R.image.speaker(),
            text: textWithAccents
        )
    }

    func recommendationModel(locale: Locale) -> ParagraphView.Model {
        let action = R.string.localizable.stakingStartChangesAction(preferredLanguages: locale.rLanguages)
        let text = R.string.localizable.stakingStartChanges(action, preferredLanguages: locale.rLanguages)
        let textWithAccents = AccentTextModel(
            text: text,
            accents: [action]
        )
        return .init(
            image: R.image.ring(),
            text: textWithAccents
        )
    }

    func testNetworkModel(
        chain: ChainModel,
        locale: Locale
    ) -> ParagraphView.Model {
        let description = R.string.localizable.stakingStartTestNetworkDescription(preferredLanguages: locale.rLanguages)
        let value = R.string.localizable.stakingStartTestNetworkTokenValue(preferredLanguages: locale.rLanguages)
        let text = R.string.localizable.stakingStartTestNetwork(chain.name, description, value, preferredLanguages: locale.rLanguages)
        let textWithAccents = AccentTextModel(
            text: text,
            accents: [description, value]
        )
        return .init(
            image: R.image.speaker(),
            text: textWithAccents
        )
    }

    func wikiModel(locale: Locale, url: URL) -> StartStakingUrlModel {
        let linkName = R.string.localizable.stakingStartWikiLink(preferredLanguages: locale.rLanguages)
        let text = R.string.localizable.stakingStartWiki(linkName, preferredLanguages: locale.rLanguages)

        return .init(
            text: text,
            url: url,
            urlName: linkName
        )
    }

    func termsModel(locale: Locale, url: URL) -> StartStakingUrlModel {
        let linkName = R.string.localizable.stakingStartTermsLink(preferredLanguages: locale.rLanguages)
        let text = R.string.localizable.stakingStartTerms(linkName, preferredLanguages: locale.rLanguages)

        return .init(
            text: text,
            url: url,
            urlName: linkName
        )
    }

    func balance(locale: Locale) -> String {
        let text = R.string.localizable.stakingStartBalanceWithFiat(
            "100 DOT",
            "$575",
            preferredLanguages: locale.rLanguages
        )
        return text
    }
}

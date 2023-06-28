import Foundation
import BigInt

protocol StartStakingViewModelFactoryProtocol {
    func earnupModel(locale: Locale) -> AccentTextModel
    func stakeModel(minStake: BigUInt?, chainAsset: ChainAsset, locale: Locale) -> ParagraphView.Model
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
    func balance(amount: BigUInt?, priceData: PriceData?, chainAsset: ChainAsset, locale: Locale) -> String
}

struct StartStakingViewModelFactory: StartStakingViewModelFactoryProtocol {
    let balanceViewModelFactory: BalanceViewModelFactoryProtocol

    init(balanceViewModelFactory: BalanceViewModelFactoryProtocol) {
        self.balanceViewModelFactory = balanceViewModelFactory
    }

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

    func stakeModel(minStake: BigUInt?, chainAsset: ChainAsset, locale: Locale) -> ParagraphView.Model {
        let time = "in 4 hours and 34 minutes"
        let precision = chainAsset.assetDisplayInfo.assetPrecision
        let textWithAccents: AccentTextModel

        if let minStake = minStake,
           let amountDecimal = Decimal.fromSubstrateAmount(minStake, precision: precision) {
            let amount = balanceViewModelFactory.amountFromValue(amountDecimal).value(for: locale)
            let text = R.string.localizable.stakingStartStake(amount, time, preferredLanguages: locale.rLanguages)
            textWithAccents = AccentTextModel(
                text: text,
                accents: [amount, time]
            )
        } else {
            let text = R.string.localizable.stakingStartStakeWithoutMinimumStake(time, preferredLanguages: locale.rLanguages)
            textWithAccents = AccentTextModel(
                text: text,
                accents: [time]
            )
        }

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

    func balance(amount: BigUInt?, priceData: PriceData?, chainAsset: ChainAsset, locale: Locale) -> String {
        let precision = chainAsset.assetDisplayInfo.assetPrecision
        guard let amountDecimal = Decimal.fromSubstrateAmount(amount ?? 0, precision: precision) else {
            return ""
        }
        let balance = balanceViewModelFactory.balanceFromPrice(amountDecimal, priceData: priceData).value(for: locale)

        if let price = balance.price, amount != nil {
            return R.string.localizable.stakingStartBalanceWithFiat(
                balance.amount,
                price,
                preferredLanguages: locale.rLanguages
            )
        } else {
            return R.string.localizable.stakingStartBalance(
                balance.amount,
                preferredLanguages: locale.rLanguages
            )
        }
    }
}

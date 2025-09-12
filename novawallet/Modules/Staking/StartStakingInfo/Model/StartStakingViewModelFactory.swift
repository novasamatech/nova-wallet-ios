import Foundation
import BigInt
import Foundation_iOS

protocol StartStakingViewModelFactoryProtocol {
    func earnupModel(
        earnings: Decimal?,
        chainAsset: ChainAsset,
        locale: Locale
    ) -> AccentTextModel
    func stakeModel(
        minStake: BigUInt?,
        rewardStartDelay: TimeInterval,
        chainAsset: ChainAsset,
        locale: Locale
    ) -> ParagraphView.Model
    func unstakeModel(unstakePeriod: TimeInterval, locale: Locale) -> ParagraphView.Model
    func rewardModel(
        amount: BigUInt?,
        chainAsset: ChainAsset,
        rewardTimeInterval: TimeInterval,
        destination: DefaultStakingRewardDestination,
        locale: Locale
    ) -> ParagraphView.Model
    func govModel(
        amount: BigUInt?,
        chainAsset: ChainAsset,
        locale: Locale
    ) -> ParagraphView.Model
    func recommendationModel(locale: Locale) -> ParagraphView.Model
    func testNetworkModel(
        chain: ChainModel,
        locale: Locale
    ) -> ParagraphView.Model
    func wikiModel(url: URL, chain: ChainModel, locale: Locale) -> StartStakingUrlModel
    func termsModel(url: URL, locale: Locale) -> StartStakingUrlModel
    func balance(amount: BigUInt?, priceData: PriceData?, chainAsset: ChainAsset, locale: Locale) -> String
    func noAccount(chain: ChainModel, locale: Locale) -> String
}

struct StartStakingViewModelFactory: StartStakingViewModelFactoryProtocol {
    let balanceViewModelFactory: BalanceViewModelFactoryProtocol
    let estimatedEarningsFormatter: LocalizableResource<NumberFormatter>

    init(
        balanceViewModelFactory: BalanceViewModelFactoryProtocol,
        estimatedEarningsFormatter: LocalizableResource<NumberFormatter>
    ) {
        self.balanceViewModelFactory = balanceViewModelFactory
        self.estimatedEarningsFormatter = estimatedEarningsFormatter
    }

    func earnupModel(
        earnings: Decimal?,
        chainAsset: ChainAsset,
        locale: Locale
    ) -> AccentTextModel {
        let amount = earnings.map { estimatedEarningsFormatter.value(for: locale).stringFromDecimal($0) } ?? ""
        let token = chainAsset.asset.displayInfo.symbol
        let value = R.string(preferredLanguages: locale.rLanguages).localizable.stakingStartEarnUp(amount ?? "")
        let text = R.string(preferredLanguages: locale.rLanguages).localizable.stakingStartEarnUpTitle(value, token)

        let textWithAccents = AccentTextModel(
            text: text,
            accents: [value]
        )
        return textWithAccents
    }

    func stakeModel(
        minStake: BigUInt?,
        rewardStartDelay: TimeInterval,
        chainAsset: ChainAsset,
        locale: Locale
    ) -> ParagraphView.Model {
        let separator = R.string(preferredLanguages: locale.rLanguages).localizable.commonAnd()
        let timePreposition = R.string(preferredLanguages: locale.rLanguages).localizable.commonTimeIn()
        let time = rewardStartDelay.localizedDaysHoursOrFallbackMinutes(
            for: locale,
            preposition: timePreposition,
            separator: separator,
            roundsDown: false
        )

        let precision = chainAsset.assetDisplayInfo.assetPrecision
        let textWithAccents: AccentTextModel

        if
            let minStake = minStake,
            minStake > 0,
            let amountDecimal = Decimal.fromSubstrateAmount(minStake, precision: precision) {
            let amount = balanceViewModelFactory.amountFromValue(amountDecimal).value(for: locale)
            let text = R.string(preferredLanguages: locale.rLanguages).localizable.stakingStartStake(amount, time)
            textWithAccents = AccentTextModel(
                text: text,
                accents: [amount, time]
            )
        } else {
            let text = R.string(
                preferredLanguages: locale.rLanguages
            ).localizable.stakingStartStakeWithoutMinimumStake(time)
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

    func unstakeModel(
        unstakePeriod: TimeInterval,
        locale: Locale
    ) -> ParagraphView.Model {
        let separator = R.string(preferredLanguages: locale.rLanguages).localizable.commonAnd()
        let preposition = R.string(preferredLanguages: locale.rLanguages).localizable.commonTimePeriodAfter()
        let unstakePeriodString = unstakePeriod.localizedDaysHoursOrFallbackMinutes(
            for: locale,
            preposition: preposition,
            separator: separator,
            roundsDown: false
        )

        let text = R.string(preferredLanguages: locale.rLanguages).localizable.stakingStartUnstake(unstakePeriodString)
        let textWithAccents = AccentTextModel(
            text: text,
            accents: [unstakePeriodString]
        )
        return .init(
            image: R.image.clock(),
            text: textWithAccents
        )
    }

    func rewardModel(
        amount: BigUInt?,
        chainAsset: ChainAsset,
        rewardTimeInterval: TimeInterval,
        destination: DefaultStakingRewardDestination,
        locale: Locale
    ) -> ParagraphView.Model {
        let separator = R.string(preferredLanguages: locale.rLanguages).localizable.commonAnd()
        let preposition = R.string(preferredLanguages: locale.rLanguages).localizable.commonTimePeriodEvery()
        let rewardIntervals = rewardTimeInterval.localizedDaysHoursOrFallbackMinutes(
            for: locale,
            preposition: preposition,
            separator: separator,
            shortcutHandler: EverydayShortcut(),
            roundsDown: false
        )

        let text: String

        if let amount = amount {
            let decimalAmount = Decimal.fromSubstrateAmount(
                amount,
                precision: Int16(chainAsset.asset.precision)
            ) ?? 0.0
            let formattedAmount = balanceViewModelFactory.amountFromValue(decimalAmount).value(for: locale)
            text = R.string(preferredLanguages: locale.rLanguages
            ).localizable.stakingStartRewardsDirectStaking(rewardIntervals, formattedAmount)
        } else {
            switch destination {
            case .balance:
                text = R.string(
                    preferredLanguages: locale.rLanguages
                ).localizable.stakingStartRewardsBalance(rewardIntervals)
            case .stake:
                text = R.string(
                    preferredLanguages: locale.rLanguages
                ).localizable.stakingStartRewardsRestake(rewardIntervals)
            case .manual:
                text = R.string(
                    preferredLanguages: locale.rLanguages
                ).localizable.stakingStartRewardsManualClaim(rewardIntervals)
            }
        }

        let textWithAccents = AccentTextModel(
            text: text,
            accents: [rewardIntervals]
        )
        return .init(
            image: R.image.cup(),
            text: textWithAccents
        )
    }

    func govModel(
        amount: BigUInt?,
        chainAsset: ChainAsset,
        locale: Locale
    ) -> ParagraphView.Model {
        let action: String
        let text: String

        if let amount = amount {
            let decimalAmount = Decimal.fromSubstrateAmount(
                amount,
                precision: Int16(chainAsset.asset.precision)
            ) ?? 0.0
            let formattedAmount = balanceViewModelFactory.amountFromValue(decimalAmount).value(for: locale)
            action = R.string(
                preferredLanguages: locale.rLanguages
            ).localizable.stakingStartGovNominationDirectStakingAction()
            text = R.string(
                preferredLanguages: locale.rLanguages
            ).localizable.stakingStartGovDirectStaking(formattedAmount, action)
        } else {
            action = R.string(preferredLanguages: locale.rLanguages).localizable.stakingStartGovNominationPoolAction()
            text = R.string(preferredLanguages: locale.rLanguages).localizable.stakingStartGovNominationPool(action)
        }

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
        let action = R.string(preferredLanguages: locale.rLanguages).localizable.stakingStartChangesAction()
        let text = R.string(preferredLanguages: locale.rLanguages).localizable.stakingStartChanges(action)
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
        let description = R.string(
            preferredLanguages: locale.rLanguages
        ).localizable.stakingStartTestNetworkDescription()
        let value = R.string(preferredLanguages: locale.rLanguages).localizable.stakingStartTestNetworkTokenValue()
        let text = R.string.localizable.stakingStartTestNetwork(
            chain.name,
            description,
            value,
            preferredLanguages: locale.rLanguages
        )
        let textWithAccents = AccentTextModel(
            text: text,
            accents: [description, value]
        )

        return .init(image: R.image.system(), text: textWithAccents)
    }

    func wikiModel(
        url: URL,
        chain: ChainModel,
        locale: Locale
    ) -> StartStakingUrlModel {
        let linkName = R.string(preferredLanguages: locale.rLanguages).localizable.stakingStartWikiLink()
        let text = R.string(preferredLanguages: locale.rLanguages).localizable.stakingStartWiki(chain.name, linkName)

        return .init(text: text, url: url, urlName: linkName)
    }

    func termsModel(url: URL, locale: Locale) -> StartStakingUrlModel {
        let linkName = R.string(preferredLanguages: locale.rLanguages).localizable.stakingStartTermsLink()
        let text = R.string(preferredLanguages: locale.rLanguages).localizable.stakingStartTerms(linkName)

        return .init(text: text, url: url, urlName: linkName)
    }

    func balance(amount: BigUInt?, priceData: PriceData?, chainAsset: ChainAsset, locale: Locale) -> String {
        let balance = balanceViewModelFactory.balanceWithPriceIfPossible(
            amount: amount,
            priceData: priceData,
            chainAsset: chainAsset
        ).value(for: locale)

        if let price = balance.price {
            return R.string(
                preferredLanguages: locale.rLanguages
            ).localizable.stakingStartBalanceWithFiat(balance.amount, price)
        } else {
            return R.string(preferredLanguages: locale.rLanguages).localizable.stakingStartBalance(balance.amount)
        }
    }

    func noAccount(chain: ChainModel, locale: Locale) -> String {
        R.string(preferredLanguages: locale.rLanguages).localizable.stakingStartNoAccount(chain.name)
    }
}

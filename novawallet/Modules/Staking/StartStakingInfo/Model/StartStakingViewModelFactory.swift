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
    func wikiModel(url: URL, chainAsset: ChainAsset, locale: Locale) -> StartStakingUrlModel
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
        let value = R.string.localizable.stakingStartEarnUp(amount ?? "", preferredLanguages: locale.rLanguages)
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

    func stakeModel(
        minStake: BigUInt?,
        rewardStartDelay: TimeInterval,
        chainAsset: ChainAsset,
        locale: Locale
    ) -> ParagraphView.Model {
        let separator = R.string.localizable.commonAnd(preferredLanguages: locale.rLanguages)
        let timePreposition = R.string.localizable.commonTimeIn(preferredLanguages: locale.rLanguages)
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
            let text = R.string.localizable.stakingStartStake(amount, time, preferredLanguages: locale.rLanguages)
            textWithAccents = AccentTextModel(
                text: text,
                accents: [amount, time]
            )
        } else {
            let text = R.string.localizable.stakingStartStakeWithoutMinimumStake(
                time,
                preferredLanguages: locale.rLanguages
            )
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
        let separator = R.string.localizable.commonAnd(preferredLanguages: locale.rLanguages)
        let preposition = R.string.localizable.commonTimePeriodAfter(preferredLanguages: locale.rLanguages)
        let unstakePeriodString = unstakePeriod.localizedDaysHoursOrFallbackMinutes(
            for: locale,
            preposition: preposition,
            separator: separator,
            roundsDown: false
        )

        let text = R.string.localizable.stakingStartUnstake(unstakePeriodString, preferredLanguages: locale.rLanguages)
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
        let separator = R.string.localizable.commonAnd(preferredLanguages: locale.rLanguages)
        let preposition = R.string.localizable.commonTimePeriodEvery(preferredLanguages: locale.rLanguages)
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
            text = R.string.localizable.stakingStartRewardsDirectStaking(
                rewardIntervals,
                formattedAmount,
                preferredLanguages: locale.rLanguages
            )
        } else {
            switch destination {
            case .balance:
                text = R.string.localizable.stakingStartRewardsBalance(
                    rewardIntervals,
                    preferredLanguages: locale.rLanguages
                )
            case .stake:
                text = R.string.localizable.stakingStartRewardsRestake(
                    rewardIntervals,
                    preferredLanguages: locale.rLanguages
                )
            case .manual:
                text = R.string.localizable.stakingStartRewardsManualClaim(
                    rewardIntervals,
                    preferredLanguages: locale.rLanguages
                )
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
            action = R.string.localizable.stakingStartGovNominationDirectStakingAction(
                preferredLanguages: locale.rLanguages
            )
            text = R.string.localizable.stakingStartGovDirectStaking(
                formattedAmount,
                action,
                preferredLanguages: locale.rLanguages
            )
        } else {
            action = R.string.localizable.stakingStartGovNominationPoolAction(preferredLanguages: locale.rLanguages)
            text = R.string.localizable.stakingStartGovNominationPool(action, preferredLanguages: locale.rLanguages)
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
        chainAsset: ChainAsset,
        locale: Locale
    ) -> StartStakingUrlModel {
        let linkName = R.string.localizable.stakingStartWikiLink(preferredLanguages: locale.rLanguages)

        let text = R.string.localizable.stakingStartWiki(
            chainAsset.chainAssetName,
            linkName,
            preferredLanguages: locale.rLanguages
        )

        return .init(text: text, url: url, urlName: linkName)
    }

    func termsModel(url: URL, locale: Locale) -> StartStakingUrlModel {
        let linkName = R.string.localizable.stakingStartTermsLink(preferredLanguages: locale.rLanguages)
        let text = R.string.localizable.stakingStartTerms(linkName, preferredLanguages: locale.rLanguages)

        return .init(text: text, url: url, urlName: linkName)
    }

    func balance(amount: BigUInt?, priceData: PriceData?, chainAsset: ChainAsset, locale: Locale) -> String {
        let balance = balanceViewModelFactory.balanceWithPriceIfPossible(
            amount: amount,
            priceData: priceData,
            chainAsset: chainAsset
        ).value(for: locale)

        if let price = balance.price {
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

    func noAccount(chain: ChainModel, locale: Locale) -> String {
        R.string.localizable.stakingStartNoAccount(chain.name, preferredLanguages: locale.rLanguages)
    }
}

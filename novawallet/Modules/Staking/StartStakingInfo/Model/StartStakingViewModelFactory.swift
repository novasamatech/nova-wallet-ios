import Foundation
import BigInt
import SoraFoundation

protocol StartStakingViewModelFactoryProtocol {
    func earnupModel(
        earnings: Decimal?,
        chainAsset: ChainAsset,
        locale: Locale
    ) -> AccentTextModel
    func stakeModel(
        minStake: BigUInt?,
        nextEra: TimeInterval,
        chainAsset: ChainAsset,
        locale: Locale
    ) -> ParagraphView.Model
    func unstakeModel(unstakePeriod: TimeInterval, locale: Locale) -> ParagraphView.Model
    func rewardModel(
        stakingType: StartStakingType,
        chainAsset: ChainAsset,
        eraDuration: TimeInterval,
        locale: Locale
    ) -> ParagraphView.Model
    func govModel(stakingType: StartStakingType, chainAsset: ChainAsset, locale: Locale) -> ParagraphView.Model
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
        nextEra: TimeInterval,
        chainAsset: ChainAsset,
        locale: Locale
    ) -> ParagraphView.Model {
        let separator = R.string.localizable.commonAnd(preferredLanguages: locale.rLanguages)
        let time = nextEra.localizedDaysHours(for: locale, separator: separator) ?? ""
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
        let unstakePeriod = preposition + " " + unstakePeriod.localizedDaysHours(
            for: locale,
            separator: separator
        )
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

    func rewardModel(
        stakingType: StartStakingType,
        chainAsset: ChainAsset,
        eraDuration: TimeInterval,
        locale: Locale
    ) -> ParagraphView.Model {
        let separator = R.string.localizable.commonAnd(preferredLanguages: locale.rLanguages)
        let rewardIntervals = eraDuration.localizedDaysHours(for: locale, separator: separator) ?? ""
        let text: String

        switch stakingType {
        case let .directStaking(plank):
            let decimalAmount = Decimal.fromSubstrateAmount(
                plank,
                precision: Int16(chainAsset.asset.precision)
            ) ?? 0.0
            let formattedAmount = balanceViewModelFactory.amountFromValue(decimalAmount).value(for: locale)
            text = R.string.localizable.stakingStartRewardsDirectStaking(
                rewardIntervals,
                formattedAmount,
                preferredLanguages: locale.rLanguages
            )
        case .nominationPool:
            text = R.string.localizable.stakingStartRewardsNominationPool(
                rewardIntervals,
                preferredLanguages: locale.rLanguages
            )
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
        stakingType: StartStakingType,
        chainAsset: ChainAsset,
        locale: Locale
    ) -> ParagraphView.Model {
        let action: String
        let text: String
        switch stakingType {
        case .nominationPool:
            action = R.string.localizable.stakingStartGovNominationPoolAction(preferredLanguages: locale.rLanguages)
            text = R.string.localizable.stakingStartGovNominationPool(action, preferredLanguages: locale.rLanguages)
        case let .directStaking(plank):
            let decimalAmount = Decimal.fromSubstrateAmount(
                plank,
                precision: Int16(chainAsset.asset.precision)
            ) ?? 0.0
            let formattedAmount = balanceViewModelFactory.amountFromValue(decimalAmount).value(for: locale)
            action = R.string.localizable.stakingStartGovNominationDirectStakingAction(preferredLanguages: locale.rLanguages)
            text = R.string.localizable.stakingStartGovDirectStaking(
                formattedAmount,
                action,
                preferredLanguages: locale.rLanguages
            )
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
        let text = R.string.localizable.stakingStartTestNetwork(chain.name, description, value, preferredLanguages: locale.rLanguages)
        let textWithAccents = AccentTextModel(
            text: text,
            accents: [description, value]
        )
        return .init(
            image: R.image.system(),
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

enum StartStakingType {
    case nominationPool
    case directStaking(amount: BigUInt)
}
import BigInt
import SoraFoundation

protocol StakingTypeViewModelFactoryProtocol {
    func directStakingViewModel(
        minStake: BigUInt?,
        chainAsset: ChainAsset,
        choice: ValidatorChoice?,
        locale: Locale
    ) -> DirectStakingTypeViewModel

    func nominationPoolViewModel(
        minStake: BigUInt?,
        chainAsset: ChainAsset,
        choice: PoolChoice?,
        locale: Locale
    ) -> PoolStakingTypeViewModel

    func minStake(
        minStake: BigUInt?,
        chainAsset: ChainAsset,
        locale: Locale
    ) -> String
}

final class StakingTypeViewModelFactory: StakingTypeViewModelFactoryProtocol {
    let balanceViewModelFactory: BalanceViewModelFactoryProtocol
    let countFormatter: LocalizableResource<NumberFormatter>

    init(
        balanceViewModelFactory: BalanceViewModelFactoryProtocol,
        countFormatter: LocalizableResource<NumberFormatter>
    ) {
        self.balanceViewModelFactory = balanceViewModelFactory
        self.countFormatter = countFormatter
    }

    func directStakingViewModel(
        minStake: BigUInt?,
        chainAsset: ChainAsset,
        choice: ValidatorChoice?,
        locale: Locale
    ) -> DirectStakingTypeViewModel {
        let strings = R.string.localizable.self
        let title = strings.stakingTypeDirect(preferredLanguages: locale.rLanguages)
        let amountDecimal = minStake.map {
            Decimal.fromSubstrateAmount($0, precision: chainAsset.assetDisplayInfo.assetPrecision)
        } ?? nil
        let amount = amountDecimal.map { balanceViewModelFactory.amountFromValue($0).value(for: locale) } ?? ""
        let minStakeString = strings.stakingTypeMinimumStake(amount, preferredLanguages: locale.rLanguages)
        let rewardsString = strings.stakingTypeAutoRewards(preferredLanguages: locale.rLanguages)
        let govString = chainAsset.chain.hasGovernance ?
            strings.stakingTypeGovReuseTokens(preferredLanguages: locale.rLanguages) : ""
        let managmentString = strings.stakingTypeStakingManagment(preferredLanguages: locale.rLanguages)

        let subtitle = [
            minStakeString,
            rewardsString,
            govString,
            managmentString
        ].joined(separator: .returnKey)

        switch choice {
        case let .recommended(maxCount):
            return .init(
                title: title,
                subtile: subtitle,
                nominatorModel: .init(
                    title: strings.stakingTypeValidatorsTitle(preferredLanguages: locale.rLanguages),
                    subtitle: strings.stakingTypeRecommendedValidatorsSubtitle(preferredLanguages: locale.rLanguages),
                    isRecommended: true,
                    count: countFormatter.value(for: locale).string(from: NSNumber(value: maxCount)) ?? ""
                )
            )
        case let .selected(count, maxCount):
            let validatorsString = strings.stakingCustomHeaderValidatorsTitle(
                count,
                maxCount,
                preferredLanguages: locale.rLanguages
            )
            return .init(
                title: title,
                subtile: subtitle,
                nominatorModel: .init(
                    title: strings.stakingTypeValidatorsTitle(preferredLanguages: locale.rLanguages),
                    subtitle: validatorsString,
                    isRecommended: false,
                    count: countFormatter.value(for: locale).string(from: NSNumber(value: count)) ?? ""
                )
            )
        case .none:
            return .init(title: title, subtile: subtitle, nominatorModel: nil)
        }
    }

    func nominationPoolViewModel(
        minStake: BigUInt?,
        chainAsset: ChainAsset,
        choice: PoolChoice?,
        locale: Locale
    ) -> PoolStakingTypeViewModel {
        let strings = R.string.localizable.self
        let title = strings.stakingTypeNominationPool(preferredLanguages: locale.rLanguages)
        let amountDecimal = minStake.map {
            Decimal.fromSubstrateAmount($0, precision: chainAsset.assetDisplayInfo.assetPrecision)
        } ?? nil
        let amount = amountDecimal.map { balanceViewModelFactory.amountFromValue($0).value(for: locale) } ?? ""
        let minStakeString = strings.stakingTypeMinimumStake(amount, preferredLanguages: locale.rLanguages)
        let rewardsString = strings.stakingTypeManualRewards(preferredLanguages: locale.rLanguages)

        let subtitle = [
            minStakeString,
            rewardsString
        ].joined(separator: .returnKey)

        guard let choice = choice else {
            return .init(title: title, subtile: subtitle, poolModel: nil)
        }

        let poolSubtitle = choice.recommended ? strings.stakingTypeRecommendedPool(preferredLanguages: locale.rLanguages) : nil

        return .init(
            title: title,
            subtile: subtitle,
            poolModel: .init(
                icon: choice.icon,
                title: choice.name,
                subtitle: poolSubtitle
            )
        )
    }

    func minStake(
        minStake: BigUInt?,
        chainAsset: ChainAsset,
        locale: Locale
    ) -> String {
        guard let minStake = minStake else {
            return ""
        }
        let strings = R.string.localizable.self
        let amountDecimal = Decimal.fromSubstrateAmount(minStake, precision: chainAsset.assetDisplayInfo.assetPrecision)
        let amount = amountDecimal.map { balanceViewModelFactory.amountFromValue($0).value(for: locale) } ?? ""
        return strings.stakingTypeMinimumStake(amount, preferredLanguages: locale.rLanguages)
    }
}

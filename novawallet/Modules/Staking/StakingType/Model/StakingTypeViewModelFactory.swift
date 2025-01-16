import BigInt
import Foundation_iOS
import SubstrateSdk

protocol StakingTypeViewModelFactoryProtocol {
    func directStakingViewModel(
        minStake: BigUInt?,
        chainAsset: ChainAsset,
        method: StakingSelectionMethod?,
        locale: Locale
    ) -> DirectStakingTypeViewModel

    func nominationPoolViewModel(
        minStake: BigUInt?,
        chainAsset: ChainAsset,
        method: StakingSelectionMethod?,
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
    let stakingViewModelFactory: SelectedStakingViewModelFactoryProtocol

    init(
        balanceViewModelFactory: BalanceViewModelFactoryProtocol,
        stakingViewModelFactory: SelectedStakingViewModelFactoryProtocol
    ) {
        self.balanceViewModelFactory = balanceViewModelFactory
        self.stakingViewModelFactory = stakingViewModelFactory
    }

    func directStakingViewModel(
        minStake: BigUInt?,
        chainAsset: ChainAsset,
        method: StakingSelectionMethod?,
        locale: Locale
    ) -> DirectStakingTypeViewModel {
        let strings = R.string.localizable.self
        let title = strings.stakingTypeDirect(preferredLanguages: locale.rLanguages)
        let amountDecimal = minStake.map {
            Decimal.fromSubstrateAmount($0, precision: chainAsset.assetDisplayInfo.assetPrecision)
        } ?? nil
        let amount = amountDecimal.map { balanceViewModelFactory.amountFromValue($0).value(for: locale) } ?? nil
        let minStakeString = amount.map {
            strings.stakingTypeMinimumStake($0, preferredLanguages: locale.rLanguages)
        } ?? nil

        let rewardsString = strings.stakingTypeAutoRewards(preferredLanguages: locale.rLanguages)
        let govString = chainAsset.chain.hasGovernance ?
            strings.stakingTypeGovReuseTokens(preferredLanguages: locale.rLanguages) : nil
        let managmentString = strings.stakingTypeStakingManagment(preferredLanguages: locale.rLanguages)

        let subtitle = [
            minStakeString,
            rewardsString,
            govString,
            managmentString
        ]
        .compactMap { $0 }
        .joined(separator: .returnKey)

        guard
            let method = method,
            case let .direct(validators) = method.selectedStakingOption else {
            return .init(title: title, subtile: subtitle, validator: nil)
        }

        let validatorViewModel = stakingViewModelFactory.createValidator(
            for: validators,
            displaysRecommended: method.shouldUseRecommendationStyle,
            locale: locale
        )

        return .init(title: title, subtile: subtitle, validator: validatorViewModel)
    }

    func nominationPoolViewModel(
        minStake: BigUInt?,
        chainAsset: ChainAsset,
        method: StakingSelectionMethod?,
        locale: Locale
    ) -> PoolStakingTypeViewModel {
        let strings = R.string.localizable.self
        let title = strings.stakingTypeNominationPool(preferredLanguages: locale.rLanguages)
        let amountDecimal = minStake.map {
            Decimal.fromSubstrateAmount($0, precision: chainAsset.assetDisplayInfo.assetPrecision)
        } ?? nil
        let amount = amountDecimal.map { balanceViewModelFactory.amountFromValue($0).value(for: locale) } ?? nil
        let minStakeString = amount.map {
            strings.stakingTypeMinimumStake($0, preferredLanguages: locale.rLanguages)
        } ?? nil
        let rewardsString = strings.stakingTypeManualRewards(preferredLanguages: locale.rLanguages)

        let subtitle = [
            minStakeString,
            rewardsString
        ]
        .compactMap { $0 }
        .joined(separator: .returnKey)

        guard
            let method = method,
            case let .pool(selectedPool) = method.selectedStakingOption else {
            return .init(title: title, subtile: subtitle, poolAccount: nil)
        }

        let poolViewModel = stakingViewModelFactory.createPool(
            for: selectedPool,
            chainAsset: chainAsset,
            displaysRecommended: method.shouldUseRecommendationStyle,
            locale: locale
        )

        return .init(title: title, subtile: subtitle, poolAccount: poolViewModel)
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

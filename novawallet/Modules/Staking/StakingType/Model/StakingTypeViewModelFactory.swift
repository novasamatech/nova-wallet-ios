import BigInt
import SoraFoundation
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
    let countFormatter: LocalizableResource<NumberFormatter>
    private lazy var iconGenerator = PolkadotIconGenerator()

    init(
        balanceViewModelFactory: BalanceViewModelFactoryProtocol,
        countFormatter: LocalizableResource<NumberFormatter>
    ) {
        self.balanceViewModelFactory = balanceViewModelFactory
        self.countFormatter = countFormatter
    }

    private func validatorAccountViewModel(method: StakingSelectionMethod?) -> ValidatorAccountViewModel? {
        guard let method = method, case let .direct(validators) = method.selectedStakingOption else {
            return nil
        }

        return method.shouldUseRecommendationStyle ? .recommended(maxCount: validators.maxTargets) :
            .selected(count: validators.targets.count, maxCount: validators.maxTargets)
    }

    private func poolAccountViewModel(method: StakingSelectionMethod?) -> PoolAccountViewModel? {
        guard let method = method, case let .pool(pool) = method.selectedStakingOption else {
            return nil
        }
        let image: ImageViewModelProtocol?
        if pool.poolId.isNovaPool {
            image = StaticImageViewModel(image: R.image.iconNova()!)
        } else {
            if let icon = try? iconGenerator.generateFromAccountId(pool.bondedAccountId) {
                image = DrawableIconViewModel(icon: icon)
            } else {
                image = nil
            }
        }

        let name: String
        if let metadata = pool.metadata, let poolName = String(data: metadata, encoding: .utf8) {
            name = poolName
        } else {
            name = "#\(pool.poolId)"
        }

        return PoolAccountViewModel(
            name: name,
            icon: image,
            recommended: method.shouldUseRecommendationStyle
        )
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

        switch validatorAccountViewModel(method: method) {
        case let .recommended(maxCount):
            return .init(
                title: title,
                subtile: subtitle,
                validator: .init(
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
                validator: .init(
                    title: strings.stakingTypeValidatorsTitle(preferredLanguages: locale.rLanguages),
                    subtitle: validatorsString,
                    isRecommended: false,
                    count: countFormatter.value(for: locale).string(from: NSNumber(value: count)) ?? ""
                )
            )
        case .none:
            return .init(title: title, subtile: subtitle, validator: nil)
        }
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
        let amount = amountDecimal.map { balanceViewModelFactory.amountFromValue($0).value(for: locale) } ?? ""
        let minStakeString = strings.stakingTypeMinimumStake(amount, preferredLanguages: locale.rLanguages)
        let rewardsString = strings.stakingTypeManualRewards(preferredLanguages: locale.rLanguages)

        let subtitle = [
            minStakeString,
            rewardsString
        ].joined(separator: .returnKey)

        guard let poolAccount = poolAccountViewModel(method: method) else {
            return .init(title: title, subtile: subtitle, poolAccount: nil)
        }

        let poolSubtitle = poolAccount.recommended ? strings.stakingTypeRecommendedPool(
            preferredLanguages: locale.rLanguages) : nil

        return .init(
            title: title,
            subtile: subtitle,
            poolAccount: .init(
                icon: poolAccount.icon,
                title: poolAccount.name,
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

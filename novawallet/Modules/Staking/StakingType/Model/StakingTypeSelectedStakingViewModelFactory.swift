import Foundation
import BigInt

final class SelectedStakingTypeViewModelFactory {
    private lazy var countFormatter = NumberFormatter.quantity.localizableResource()
    private lazy var poolIconFactory = NominationPoolsIconFactory()
}

extension SelectedStakingTypeViewModelFactory: SelectedStakingViewModelFactoryProtocol {
    func createRecommended(
        for stakingType: SelectedStakingOption,
        locale: Locale
    ) -> RecommendedStakingTypeViewModel {
        switch stakingType {
        case .direct:
            return RecommendedStakingTypeViewModel(
                title: R.string.localizable.stakingDirectStaking(preferredLanguages: locale.rLanguages),
                subtitle: R.string.localizable.commonRecommended(preferredLanguages: locale.rLanguages)
            )
        case .pool:
            return RecommendedStakingTypeViewModel(
                title: R.string.localizable.stakingPoolStaking(preferredLanguages: locale.rLanguages),
                subtitle: R.string.localizable.commonRecommended(preferredLanguages: locale.rLanguages)
            )
        }
    }

    func createValidator(
        for validators: PreparedValidators,
        displaysRecommended: Bool,
        locale: Locale
    ) -> DirectStakingTypeViewModel.ValidatorModel {
        let strings = R.string.localizable.self

        if displaysRecommended {
            return .init(
                title: strings.stakingTypeValidatorsTitle(preferredLanguages: locale.rLanguages),
                subtitle: strings.stakingTypeRecommendedValidatorsSubtitle(preferredLanguages: locale.rLanguages),
                isRecommended: true,
                count: countFormatter.value(for: locale).string(from: NSNumber(value: validators.targets.count)) ?? ""
            )
        } else {
            let validatorsString = strings.stakingSetupAmountDirectTypeSubtitle(
                validators.targets.count,
                validators.maxTargets,
                preferredLanguages: locale.rLanguages
            )

            return .init(
                title: strings.stakingTypeValidatorsTitle(preferredLanguages: locale.rLanguages),
                subtitle: validatorsString,
                isRecommended: false,
                count: countFormatter.value(for: locale).string(from: NSNumber(value: validators.targets.count)) ?? ""
            )
        }
    }

    func createPool(
        for pool: NominationPools.SelectedPool,
        chainAsset: ChainAsset,
        displaysRecommended: Bool,
        locale: Locale
    ) -> PoolStakingTypeViewModel.PoolAccountModel {
        let iconViewModel = poolIconFactory.createIconViewModel(
            for: chainAsset,
            poolId: pool.poolId,
            bondedAccountId: pool.bondedAccountId
        )

        let title = pool.title(for: chainAsset.chain.chainFormat) ?? ""

        let subtitle = displaysRecommended ? R.string.localizable.commonRecommended(
            preferredLanguages: locale.rLanguages
        ) : nil

        return PoolStakingTypeViewModel.PoolAccountModel(
            icon: iconViewModel,
            title: title,
            subtitle: subtitle,
            isRecommended: displaysRecommended
        )
    }
}

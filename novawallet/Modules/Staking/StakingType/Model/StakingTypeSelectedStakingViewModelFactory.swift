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
                title: R.string(preferredLanguages: locale.rLanguages).localizable.stakingTypeDirect(),
                subtitle: R.string(preferredLanguages: locale.rLanguages).localizable.commonRecommended()
            )
        case .pool:
            return RecommendedStakingTypeViewModel(
                title: R.string(preferredLanguages: locale.rLanguages).localizable.stakingTypeNominationPool(),
                subtitle: R.string(preferredLanguages: locale.rLanguages).localizable.commonRecommended()
            )
        }
    }

    func createValidator(
        for validators: PreparedValidators,
        displaysRecommended: Bool,
        locale: Locale
    ) -> DirectStakingTypeViewModel.ValidatorModel {
        let strings = R.string(preferredLanguages: locale.rLanguages).localizable.self

        if displaysRecommended {
            return .init(
                title: strings.stakingRecommendedTitle(),
                subtitle: strings.commonRecommended(),
                isRecommended: true,
                count: countFormatter.value(for: locale).string(from: NSNumber(value: validators.targets.count)) ?? ""
            )
        } else {
            let validatorsString = strings.stakingSetupAmountDirectTypeSubtitle(
                validators.targets.count,
                validators.maxTargets
            )

            return .init(
                title: strings.stakingRecommendedTitle(),
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

        let subtitle = displaysRecommended ? R.string(
            preferredLanguages: locale.rLanguages
        ).localizable.commonRecommended() : nil

        return PoolStakingTypeViewModel.PoolAccountModel(
            icon: iconViewModel,
            title: title,
            subtitle: subtitle,
            isRecommended: displaysRecommended
        )
    }
}

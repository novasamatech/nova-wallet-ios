import Foundation
import Foundation_iOS
import BigInt

protocol SelectedStakingViewModelFactoryProtocol {
    func createRecommended(
        for stakingType: SelectedStakingOption,
        locale: Locale
    ) -> RecommendedStakingTypeViewModel

    func createValidator(
        for validators: PreparedValidators,
        displaysRecommended: Bool,
        locale: Locale
    ) -> DirectStakingTypeViewModel.ValidatorModel

    func createPool(
        for pool: NominationPools.SelectedPool,
        chainAsset: ChainAsset,
        displaysRecommended: Bool,
        locale: Locale
    ) -> PoolStakingTypeViewModel.PoolAccountModel
}

final class SelectedStakingViewModelFactory {}

extension SelectedStakingViewModelFactory: SelectedStakingViewModelFactoryProtocol {
    func createRecommended(
        for stakingType: SelectedStakingOption,
        locale: Locale
    ) -> RecommendedStakingTypeViewModel {
        switch stakingType {
        case .direct:
            return RecommendedStakingTypeViewModel(
                title: R.string.localizable.stakingTypeDirect(preferredLanguages: locale.rLanguages),
                subtitle: R.string.localizable.commonRecommended(preferredLanguages: locale.rLanguages)
            )
        case .pool:
            return RecommendedStakingTypeViewModel(
                title: R.string.localizable.stakingTypeNominationPool(preferredLanguages: locale.rLanguages),
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
                title: strings.stakingTypeDirect(preferredLanguages: locale.rLanguages),
                subtitle: strings.commonRecommended(preferredLanguages: locale.rLanguages),
                isRecommended: true,
                count: nil
            )
        } else {
            let validatorsString = strings.stakingCustomHeaderValidatorsTitle(
                validators.targets.count,
                validators.maxTargets,
                preferredLanguages: locale.rLanguages
            )

            return .init(
                title: strings.stakingTypeDirect(preferredLanguages: locale.rLanguages),
                subtitle: validatorsString,
                isRecommended: false,
                count: nil
            )
        }
    }

    func createPool(
        for pool: NominationPools.SelectedPool,
        chainAsset: ChainAsset,
        displaysRecommended: Bool,
        locale: Locale
    ) -> PoolStakingTypeViewModel.PoolAccountModel {
        let poolName = pool.title(for: chainAsset.chain.chainFormat) ?? ""
        let title = R.string.localizable.stakingTypeNominationPool(preferredLanguages: locale.rLanguages)
        let subtitle = displaysRecommended ? R.string.localizable.commonRecommended(
            preferredLanguages: locale.rLanguages
        ) : poolName

        return PoolStakingTypeViewModel.PoolAccountModel(
            icon: nil,
            title: title,
            subtitle: subtitle,
            isRecommended: displaysRecommended
        )
    }
}

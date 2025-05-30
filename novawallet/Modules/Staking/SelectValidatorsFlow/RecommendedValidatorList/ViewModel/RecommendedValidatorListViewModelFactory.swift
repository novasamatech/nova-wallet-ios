import Foundation
import SubstrateSdk
import Foundation_iOS

protocol RecommendedValidatorListViewModelFactoryProtocol {
    func createViewModel(
        from validators: [SelectedValidatorInfo],
        maxTargets: Int
    ) throws -> RecommendedValidatorListViewModelProtocol
}

final class RecommendedValidatorListViewModelFactory {
    private let iconGenerator: IconGenerating

    init(
        iconGenerator: IconGenerating
    ) {
        self.iconGenerator = iconGenerator
    }

    private func createStakeReturnString(from stakeReturn: Decimal?) -> LocalizableResource<String> {
        LocalizableResource { locale in
            guard let stakeReturn = stakeReturn, stakeReturn > 0 else { return "" }

            let percentageFormatter = NumberFormatter.percent.localizableResource().value(for: locale)

            return percentageFormatter.string(from: stakeReturn as NSNumber) ?? ""
        }
    }

    private func createItemsCountString(for currentCount: Int, outOf maxCount: Int) -> LocalizableResource<String> {
        LocalizableResource { locale in
            R.string.localizable.stakingSelectedValidatorsCount_v191(
                currentCount,
                maxCount,
                preferredLanguages: locale.rLanguages
            )
        }
    }
}

extension RecommendedValidatorListViewModelFactory: RecommendedValidatorListViewModelFactoryProtocol {
    func createViewModel(
        from validators: [SelectedValidatorInfo],
        maxTargets: Int
    ) throws -> RecommendedValidatorListViewModelProtocol {
        let items: [LocalizableResource<RecommendedValidatorViewModelProtocol>] =
            try validators.map { validator in
                let icon = try iconGenerator.generateFromAddress(validator.address)
                let title = validator.identity?.displayName ?? validator.address

                let details = createStakeReturnString(from: validator.stakeInfo?.stakeReturn)

                return LocalizableResource { locale in
                    RecommendedValidatorViewModel(
                        icon: icon,
                        title: title,
                        details: details.value(for: locale)
                    )
                }
            }

        let itemsCountString = createItemsCountString(for: items.count, outOf: maxTargets)

        return RecommendedValidatorListViewModel(
            itemsCountString: itemsCountString,
            itemViewModels: items
        )
    }
}

import Foundation
import SubstrateSdk
import Foundation_iOS

final class ValidatorSearchViewModelFactory {
    private lazy var iconGenerator = PolkadotIconGenerator()

    private func createHeaderViewModel(
        displayValidatorsCount: Int,
        locale: Locale
    ) -> TitleWithSubtitleViewModel {
        let title = R.string(preferredLanguages: locale.rLanguages
        ).localizable.commonSearchResultsNumber(displayValidatorsCount)

        let subtitle = R.string(preferredLanguages: locale.rLanguages).localizable.stakingFilterTitleRewards()

        return TitleWithSubtitleViewModel(title: title, subtitle: subtitle)
    }

    private func createCellsViewModel(
        from displayValidatorList: [SelectedValidatorInfo],
        selectedValidatorList: [SelectedValidatorInfo],
        locale: Locale
    ) -> [ValidatorSearchCellViewModel] {
        let apyFormatter = NumberFormatter.percent.localizableResource().value(for: locale)

        return displayValidatorList.map { validator in
            let icon = try? self.iconGenerator.generateFromAddress(validator.address)

            let detailsText = apyFormatter.string(
                from: validator.stakeReturn as NSNumber
            )

            return ValidatorSearchCellViewModel(
                icon: icon,
                name: validator.identity?.displayName,
                address: validator.address,
                details: detailsText,
                shouldShowWarning: validator.oversubscribed,
                shouldShowError: validator.hasSlashes,
                isSelected: selectedValidatorList.contains(validator)
            )
        }
    }

    func createEmptyModel() -> ValidatorSearchViewModel {
        ValidatorSearchViewModel(
            headerViewModel: nil,
            cellViewModels: []
        )
    }
}

extension ValidatorSearchViewModelFactory: ValidatorSearchViewModelFactoryProtocol {
    func createViewModel(
        from displayValidatorList: [SelectedValidatorInfo],
        selectedValidatorList: [SelectedValidatorInfo],
        referenceValidatorList: [SelectedValidatorInfo],
        locale: Locale
    ) -> ValidatorSearchViewModel {
        guard !displayValidatorList.isEmpty else {
            return createEmptyModel()
        }

        let headerViewModel = createHeaderViewModel(
            displayValidatorsCount: displayValidatorList.count,
            locale: locale
        )

        let cellsViewModel = createCellsViewModel(
            from: displayValidatorList,
            selectedValidatorList: selectedValidatorList,
            locale: locale
        )

        let differsFromInitial = selectedValidatorList != referenceValidatorList

        return ValidatorSearchViewModel(
            headerViewModel: headerViewModel,
            cellViewModels: cellsViewModel,
            differsFromInitial: differsFromInitial
        )
    }
}

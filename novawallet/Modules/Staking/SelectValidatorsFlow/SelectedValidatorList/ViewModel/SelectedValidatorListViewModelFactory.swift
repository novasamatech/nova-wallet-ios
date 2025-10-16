import Foundation
import SubstrateSdk
import Foundation_iOS

final class SelectedValidatorListViewModelFactory {
    private lazy var iconGenerator = PolkadotIconGenerator()
    private func createHeaderViewModel(
        displayValidatorsCount: Int,
        totalValidatorsCount: Int,
        locale: Locale
    ) -> TitleWithSubtitleViewModel {
        let title = R.string(preferredLanguages: locale.rLanguages
        ).localizable.stakingCustomHeaderValidatorsTitle(displayValidatorsCount, totalValidatorsCount)

        let subtitle = R.string(preferredLanguages: locale.rLanguages).localizable.stakingFilterTitleRewards()

        return TitleWithSubtitleViewModel(
            title: title,
            subtitle: subtitle
        )
    }

    private func createCellsViewModel(
        from validatorList: [SelectedValidatorInfo],
        locale: Locale
    ) -> [SelectedValidatorCellViewModel] {
        let apyFormatter = NumberFormatter.percent.localizableResource().value(for: locale)

        return validatorList.map { validator in
            let icon = try? self.iconGenerator.generateFromAddress(validator.address)

            let detailsText = validator.stakeReturn > 0 ?
                apyFormatter.string(from: validator.stakeReturn as NSNumber) : ""

            return SelectedValidatorCellViewModel(
                icon: icon,
                name: validator.identity?.displayName,
                address: validator.address,
                details: detailsText,
                shouldShowWarning: validator.oversubscribed,
                shouldShowError: validator.hasSlashes
            )
        }
    }
}

extension SelectedValidatorListViewModelFactory: SelectedValidatorListViewModelFactoryProtocol {
    func createViewModel(
        from validatorList: [SelectedValidatorInfo],
        totalValidatorsCount: Int,
        locale: Locale
    ) -> SelectedValidatorListViewModel {
        let headerViewModel = createHeaderViewModel(
            displayValidatorsCount: validatorList.count,
            totalValidatorsCount: totalValidatorsCount,
            locale: locale
        )

        let cellsViewModel = createCellsViewModel(
            from: validatorList,
            locale: locale
        )

        return SelectedValidatorListViewModel(
            headerViewModel: headerViewModel,
            cellViewModels: cellsViewModel,
            limitIsExceeded: validatorList.count > totalValidatorsCount
        )
    }
}

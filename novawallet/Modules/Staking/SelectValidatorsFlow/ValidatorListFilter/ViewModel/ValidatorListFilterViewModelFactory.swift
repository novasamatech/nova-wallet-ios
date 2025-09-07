import Foundation

protocol ValidatorListFilterViewModelFactoryProtocol {
    func createViewModel(
        from filter: CustomValidatorListFilter,
        initialFilter: CustomValidatorListFilter,
        hasIdentity: Bool,
        token: String,
        locale: Locale
    ) -> ValidatorListFilterViewModel
}

struct ValidatorListFilterViewModelFactory {
    private func createFilterViewModelSection(
        from filter: CustomValidatorListFilter,
        hasIdentity: Bool,
        locale: Locale
    ) -> ValidatorListFilterViewModelSection<ValidatorListFilterRow> {
        let filters: [ValidatorListFilterRow]

        if hasIdentity {
            filters = [.withoutIdentity, .slashed, .oversubscribed, .clusterLimit]
        } else {
            filters = [.slashed, .oversubscribed]
        }

        let cellViewModels: [ValidatorListFilterCellViewModel<ValidatorListFilterRow>] = filters.map { row in
            let internalViewModel: SelectableViewModel<TitleWithSubtitleViewModel>

            switch row {
            case .withoutIdentity:
                internalViewModel = SelectableViewModel(
                    underlyingViewModel: row.titleSubtitleViewModel.value(for: locale),
                    selectable: !filter.allowsNoIdentity
                )

            case .slashed:
                internalViewModel = SelectableViewModel(
                    underlyingViewModel: row.titleSubtitleViewModel.value(for: locale),
                    selectable: !filter.allowsSlashed
                )

            case .oversubscribed:
                internalViewModel = SelectableViewModel(
                    underlyingViewModel: row.titleSubtitleViewModel.value(for: locale),
                    selectable: !filter.allowsOversubscribed
                )

            case .clusterLimit:
                let allowsUnlimitedClusters = filter.allowsClusters == .unlimited
                internalViewModel = SelectableViewModel(
                    underlyingViewModel: row.titleSubtitleViewModel.value(for: locale),
                    selectable: !allowsUnlimitedClusters
                )
            }

            return ValidatorListFilterCellViewModel(type: row, viewModel: internalViewModel)
        }

        let title = R.string(preferredLanguages: locale.rLanguages
        ).localizable.walletFiltersHeader()

        return ValidatorListFilterViewModelSection(
            title: title,
            cellViewModels: cellViewModels
        )
    }

    private func createSortViewModelSection(
        from filter: CustomValidatorListFilter,
        token: String,
        locale: Locale
    ) -> ValidatorListFilterViewModelSection<ValidatorListSortRow> {
        let sortings = ValidatorListSortRow.allCases

        let cellViewModels: [ValidatorListFilterCellViewModel<ValidatorListSortRow>] = sortings.map { row in
            let internalViewModel: SelectableViewModel<TitleWithSubtitleViewModel>

            switch row {
            case .estimatedReward:
                let titleSubtitleViewModel = TitleWithSubtitleViewModel(
                    title: R.string(preferredLanguages: locale.rLanguages
                    ).localizable.stakingValidatorApyPercent()
                )

                internalViewModel = SelectableViewModel(
                    underlyingViewModel: titleSubtitleViewModel,
                    selectable: filter.sortedBy == .estimatedReward
                )

            case .ownStake:
                let titleSubtitleViewModel = TitleWithSubtitleViewModel(
                    title: R.string(preferredLanguages: locale.rLanguages
                    ).localizable.stakingFilterTitleOwnStakeToken(token)
                )

                internalViewModel = SelectableViewModel(
                    underlyingViewModel: titleSubtitleViewModel,
                    selectable: filter.sortedBy == .ownStake
                )

            case .totalStake:
                let titleSubtitleViewModel = TitleWithSubtitleViewModel(
                    title: R.string(preferredLanguages: locale.rLanguages
                    ).localizable.stakingValidatorTotalStakeToken(token)
                )

                internalViewModel = SelectableViewModel(
                    underlyingViewModel: titleSubtitleViewModel,
                    selectable: filter.sortedBy == .totalStake
                )
            }

            return ValidatorListFilterCellViewModel(type: row, viewModel: internalViewModel)
        }

        let sectionTitle = R.string(preferredLanguages: locale.rLanguages
        ).localizable.commonFilterSortHeader()

        return ValidatorListFilterViewModelSection(
            title: sectionTitle,
            cellViewModels: cellViewModels
        )
    }
}

extension ValidatorListFilterViewModelFactory: ValidatorListFilterViewModelFactoryProtocol {
    func createViewModel(
        from filter: CustomValidatorListFilter,
        initialFilter: CustomValidatorListFilter,
        hasIdentity: Bool,
        token: String,
        locale: Locale
    ) -> ValidatorListFilterViewModel {
        ValidatorListFilterViewModel(
            filterModel: createFilterViewModelSection(from: filter, hasIdentity: hasIdentity, locale: locale),
            sortModel: createSortViewModelSection(from: filter, token: token, locale: locale),
            canApply: filter != initialFilter,
            canReset: filter != CustomValidatorListFilter.recommendedFilter(havingIdentity: hasIdentity)
        )
    }
}

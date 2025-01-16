import Foundation_iOS

struct ValidatorListFilterViewModel {
    let filterModel: ValidatorListFilterViewModelSection<ValidatorListFilterRow>
    let sortModel: ValidatorListFilterViewModelSection<ValidatorListSortRow>
    let canApply: Bool
    let canReset: Bool
}

struct ValidatorListFilterCellViewModel<RowType> {
    let type: RowType
    let viewModel: SelectableViewModel<TitleWithSubtitleViewModel>
}

struct ValidatorListFilterViewModelSection<RowType> {
    let title: String
    let cellViewModels: [ValidatorListFilterCellViewModel<RowType>]
}

enum ValidatorListFilterRow: Int, CaseIterable {
    case withoutIdentity
    case slashed
    case oversubscribed
    case clusterLimit

    var titleSubtitleViewModel: LocalizableResource<TitleWithSubtitleViewModel> {
        switch self {
        case .slashed:
            return LocalizableResource { locale in
                TitleWithSubtitleViewModel(
                    title: R.string.localizable
                        .stakingRecommendedHint4(preferredLanguages: locale.rLanguages)
                )
            }

        case .oversubscribed:
            return LocalizableResource { locale in
                TitleWithSubtitleViewModel(
                    title: R.string.localizable
                        .stakingRecommendedHint2(preferredLanguages: locale.rLanguages)
                )
            }

        case .clusterLimit:
            return LocalizableResource { locale in
                TitleWithSubtitleViewModel(
                    title: R.string.localizable
                        .stakingRecommendedHint5(preferredLanguages: locale.rLanguages)
                )
            }

        case .withoutIdentity:
            return LocalizableResource { locale in
                TitleWithSubtitleViewModel(
                    title: R.string.localizable
                        .stakingRecommendedHint3(preferredLanguages: locale.rLanguages),
                    subtitle: R.string.localizable
                        .stakingRecommendedHint3Addition(preferredLanguages: locale.rLanguages)
                )
            }
        }
    }
}

enum ValidatorListSortRow: Int, CaseIterable {
    case estimatedReward
    case totalStake
    case ownStake

    var sortCriterion: CustomValidatorListFilter.CustomValidatorListSort {
        switch self {
        case .estimatedReward:
            return .estimatedReward
        case .ownStake:
            return .ownStake
        case .totalStake:
            return .totalStake
        }
    }
}

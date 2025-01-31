import Foundation
import SubstrateSdk

struct CollatorSelectionViewModel {
    let identifier: AccountId
    let iconViewModel: DrawableIcon
    let collator: DisplayAddressViewModel
    let detailsName: String
    let details: String
    let sortedByTitle: String
    let sortedByDetails: String
    let hasWarning: Bool
}

struct CollatorSelectionScreenViewModel {
    let collators: [CollatorSelectionViewModel]
    let sorting: CollatorsSortType
    let header: TitleWithSubtitleViewModel
    let filtersApplied: Bool
}

typealias CollatorSelectionState = GenericViewState<CollatorSelectionScreenViewModel>

import Foundation
import SubstrateSdk

struct CollatorSelectionViewModel {
    let iconViewModel: DrawableIcon
    let collator: DisplayAddressViewModel
    let detailsName: String
    let details: String
    let sortedByTitle: String
    let sortedByDetails: String
}

struct CollatorSelectionScreenViewModel {
    let collators: [CollatorSelectionViewModel]
    let sorting: CollatorsSortType
    let header: TitleWithSubtitleViewModel
}

typealias CollatorSelectionState = GenericViewState<CollatorSelectionScreenViewModel>

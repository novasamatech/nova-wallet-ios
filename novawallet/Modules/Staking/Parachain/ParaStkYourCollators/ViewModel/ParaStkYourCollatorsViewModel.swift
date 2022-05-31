import Foundation

struct ParaStkYourCollatorsListViewModel {
    let hasCollatorWithoutRewards: Bool
    let sections: [ParaStkYourCollatorListSection]
}

struct ParaStkYourCollatorListSection {
    let status: ParaStkYourCollatorListSectionStatus
    let collators: [CollatorSelectionViewModel]
}

enum ParaStkYourCollatorListSectionStatus {
    case rewarded
    case notRewarded
    case notElected
    case pending
}

typealias ParaStkYourCollatorsState = GenericViewState<ParaStkYourCollatorsListViewModel>

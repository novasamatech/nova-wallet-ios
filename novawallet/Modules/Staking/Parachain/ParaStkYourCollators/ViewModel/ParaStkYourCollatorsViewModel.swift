import Foundation

struct ParaStkYourCollatorsListViewModel {
    let hasCollatorWithoutRewards: Bool
    let sections: [ParaStkYourCollatorListSection]
}

struct ParaStkYourCollatorListSection {
    let status: ParaStkDelegationStatus
    let collators: [CollatorSelectionViewModel]
}

enum ParaStkDelegationStatus {
    case rewarded
    case notRewarded
    case notElected
    case pending
}

typealias ParaStkYourCollatorsState = GenericViewState<ParaStkYourCollatorsListViewModel>

import Foundation

struct CollatorStkYourCollatorsListViewModel {
    let hasCollatorWithoutRewards: Bool
    let sections: [CollatorStkYourCollatorListSection]
}

struct CollatorStkYourCollatorListSection {
    let status: CollatorStakingDelegationStatus
    let collators: [CollatorSelectionViewModel]
}

typealias ParaStkYourCollatorsState = GenericViewState<CollatorStkYourCollatorsListViewModel>

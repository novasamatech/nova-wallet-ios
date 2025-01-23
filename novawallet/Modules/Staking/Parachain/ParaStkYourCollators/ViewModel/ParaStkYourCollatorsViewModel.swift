import Foundation

struct ParaStkYourCollatorsListViewModel {
    let hasCollatorWithoutRewards: Bool
    let sections: [ParaStkYourCollatorListSection]
}

struct ParaStkYourCollatorListSection {
    let status: CollatorStakingDelegationStatus
    let collators: [CollatorSelectionViewModel]
}

typealias ParaStkYourCollatorsState = GenericViewState<ParaStkYourCollatorsListViewModel>

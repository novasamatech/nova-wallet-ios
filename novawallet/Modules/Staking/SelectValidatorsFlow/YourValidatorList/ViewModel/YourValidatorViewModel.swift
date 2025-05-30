import Foundation
import Foundation_iOS
import SubstrateSdk

enum YourValidatorListViewState {
    case loading
    case validatorList(viewModel: YourValidatorListViewModel)
    case error(String)
}

struct YourValidatorListViewModel {
    let allValidatorWithoutRewards: Bool
    let sections: [YourValidatorListSection]
}

struct YourValidatorListSection {
    let status: YourValidatorListSectionStatus
    let validators: [YourValidatorViewModel]
}

enum YourValidatorListSectionStatus {
    case stakeAllocated
    case stakeNotAllocated
    case unelected
    case pending
}

struct YourValidatorViewModel {
    let address: AccountAddress
    let icon: DrawableIcon
    let name: String?
    let amount: String?
    let apy: String?
    let shouldHaveWarning: Bool
    let shouldHaveError: Bool
}

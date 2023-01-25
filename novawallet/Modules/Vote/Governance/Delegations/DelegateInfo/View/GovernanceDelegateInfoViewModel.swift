import Foundation

enum GovernanceDelegateInfoViewModel {
    struct Delegate {
        let addressViewModel: DisplayAddressViewModel
        let details: String?
        let type: GovernanceDelegateTypeView.Model?
    }

    struct Stats {
        let delegations: String?
        let votes: String?
        let recentVotes: String?
        let allVotes: String?
    }

    struct YourDelegation {
        // TODO: Task #860pmdth8
    }
}

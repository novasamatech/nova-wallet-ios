import Foundation

enum GovernanceDelegateInfoViewModel {
    struct Delegate {
        let addressViewModel: DisplayAddressViewModel
        let details: String?
        let type: GovernanceDelegateTypeView.Model?
        let hasFullDescription: Bool
    }

    struct Stats {
        let delegations: String?
        let delegatedVotes: String?
        let recentVotes: RecentVotes?
        let allVotes: String?
    }

    struct RecentVotes {
        let period: String
        let value: String
    }

    struct YourDelegation {
        // TODO: Task #860pmdth8
    }
}

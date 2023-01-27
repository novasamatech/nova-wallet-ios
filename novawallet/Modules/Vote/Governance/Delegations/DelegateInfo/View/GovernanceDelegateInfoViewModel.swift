import Foundation

enum GovernanceDelegateInfoViewModel {
    struct Delegate {
        let profileViewModel: GovernanceDelegateProfileView.Model?
        let addressViewModel: DisplayAddressViewModel
        let details: String?
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

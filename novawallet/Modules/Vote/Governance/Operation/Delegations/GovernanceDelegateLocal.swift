import Foundation

struct GovernanceDelegateLocal {
    let stats: GovernanceDelegateStats
    let metadata: GovernanceDelegateMetadataRemote?
    let identity: AccountIdentity?

    var displayName: String? {
        identity?.displayName ?? metadata?.name
    }
}

extension Array where Array.Element == GovernanceDelegateLocal {
    func sortedByOrder(_ order: GovernanceDelegatesOrder) -> [GovernanceDelegateLocal] {
        sorted { delegate1, delegate2 in
            if delegate1.metadata != nil, delegate2.metadata == nil {
                return true
            } else if delegate1.metadata == nil, delegate2.metadata != nil {
                return false
            } else if !order.isSame(delegate1, delegate2: delegate2) {
                return order.isDescending(delegate1, delegate2: delegate2)
            } else {
                let name1 = delegate1.displayName ?? delegate1.stats.address
                let name2 = delegate2.displayName ?? delegate2.stats.address

                return name1.localizedCaseInsensitiveCompare(name2) == .orderedAscending
            }
        }
    }
}

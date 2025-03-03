import Foundation

enum CollatorsSortType: Equatable {
    case rewards
    case minStake
    case totalStake
    case ownStake

    static var defaultType: CollatorsSortType { .rewards }
}

extension Array where Element == CollatorStakingSelectionInfoProtocol {
    func sortedByType(
        _ type: CollatorsSortType,
        preferredCollators: Set<AccountId>
    ) -> [CollatorStakingSelectionInfoProtocol] {
        sorted { item1, item2 in
            CompoundComparator.compare(list: [
                {
                    let isItem1Pref = preferredCollators.contains(item1.accountId)
                    let isItem2Pref = preferredCollators.contains(item2.accountId)

                    if isItem1Pref, !isItem2Pref {
                        return .orderedAscending
                    } else if !isItem1Pref, isItem2Pref {
                        return .orderedDescending
                    } else {
                        return .orderedSame
                    }
                }, {
                    switch type {
                    case .rewards:
                        return (item1.apr ?? 0) > (item2.apr ?? 0) ? .orderedAscending : .orderedDescending
                    case .minStake:
                        return item1.minRewardableStake < item2.minRewardableStake ? .orderedAscending :
                            .orderedDescending
                    case .totalStake:
                        return item1.totalStake > item2.totalStake ? .orderedAscending :
                            .orderedDescending
                    case .ownStake:
                        let own1 = item1.ownStake ?? 0
                        let own2 = item2.ownStake ?? 0

                        return own1 > own2 ? .orderedAscending : .orderedDescending
                    }
                }
            ])
        }
    }
}

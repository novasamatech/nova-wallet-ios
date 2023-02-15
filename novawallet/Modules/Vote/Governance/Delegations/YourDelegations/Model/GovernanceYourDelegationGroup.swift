import Foundation
import BigInt

struct GovernanceYourDelegationGroup {
    let delegateModel: GovernanceDelegateLocal
    let delegations: [ReferendumDelegatingLocal]
    let tracks: [GovernanceTrackInfoLocal]

    func totalVotes() -> BigUInt {
        delegations.reduce(BigUInt(0)) { accum, delegation in
            let votes = delegation.conviction.votes(for: delegation.balance) ?? 0
            return accum + votes
        }
    }
}

extension GovernanceYourDelegationGroup {
    static func createGroups(
        from delegates: [GovernanceDelegateLocal],
        delegations: [TrackIdLocal: ReferendumDelegatingLocal],
        tracks: [GovernanceTrackInfoLocal],
        chain: ChainModel
    ) -> [GovernanceYourDelegationGroup] {
        let delegateIds = Set(delegations.values.map(\.target))

        let delegatesDict = delegates.reduce(into: [AccountId: GovernanceDelegateLocal]()) { accum, delegate in
            guard let accountId = try? delegate.stats.address.toAccountId(using: chain.chainFormat) else {
                return
            }

            accum[accountId] = delegate
        }

        let groups: [GovernanceYourDelegationGroup] = delegateIds.compactMap { delegateId in
            let delegate: GovernanceDelegateLocal

            if let currentDelegate = delegatesDict[delegateId] {
                delegate = currentDelegate
            } else {
                let address = (try? delegateId.toAddress(using: chain.chainFormat)) ?? delegateId.toHex()
                delegate = .init(
                    stats: .init(address: address, delegationsCount: 1, delegatedVotes: 0, recentVotes: 0),
                    metadata: nil,
                    identity: nil
                )
            }

            let delegationKeyValue = delegations.filter {
                $0.value.target == delegateId
            }.map { $0 }

            let delegations = delegationKeyValue.map(\.value)
            let delegationTracks = delegationKeyValue.compactMap { keyValue in
                tracks.first { $0.trackId == keyValue.key }
            }.sorted(by: { $0.trackId < $1.trackId })

            return GovernanceYourDelegationGroup(
                delegateModel: delegate,
                delegations: delegations,
                tracks: delegationTracks
            )
        }

        return groups.sorted { group1, group2 in
            if group1.delegateModel.metadata != nil, group2.delegateModel.metadata == nil {
                return true
            } else if group1.delegateModel.metadata == nil, group2.delegateModel.metadata != nil {
                return false
            } else {
                let totalVotes1 = group1.totalVotes()
                let totalVotes2 = group2.totalVotes()

                if totalVotes1 != totalVotes2 {
                    return totalVotes1 > totalVotes2
                } else {
                    return group1.delegateModel.identifier.localizedCompare(
                        group2.delegateModel.identifier
                    ) == .orderedAscending
                }
            }
        }
    }
}

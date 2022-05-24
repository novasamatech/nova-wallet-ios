import Foundation

extension ParachainStaking {
    struct DelegatorPendingCollator {
        let bond: ParachainStaking.Bond
        let hasEnoughBond: Bool
    }

    enum DelegatorRoundState {
        case active(response: DelegatorCollatorsResponse)
        case waiting(response: DelegatorCollatorsResponse)
        case inactive(response: DelegatorCollatorsResponse)

        init(response: DelegatorCollatorsResponse, delegator: ParachainStaking.Delegator) {
            if response.notRewardableCollatorsCount < delegator.delegations.count {
                self = .active(response: response)
            } else if response.pending.contains(where: { $0.hasEnoughBond }) {
                self = .waiting(response: response)
            } else {
                self = .inactive(response: response)
            }
        }
    }

    struct DelegatorCollatorsResponse {
        let pending: [DelegatorPendingCollator]
        let notElected: Set<AccountId>

        var notRewardableCollatorsCount: Int {
            pending.count + notElected.count
        }

        static var empty: DelegatorCollatorsResponse {
            DelegatorCollatorsResponse(pending: [], notElected: [])
        }
    }
}

extension SelectedRoundCollators {
    func fetchRoundState(
        for delegator: ParachainStaking.Delegator,
        accountId: AccountId,
        maxRewardableDelegators: UInt32
    ) -> ParachainStaking.DelegatorCollatorsResponse {
        let collatorsDict: [AccountId: ParachainStaking.CollatorSnapshot] = collators.reduce(
            into: [:]
        ) { result, collator in
            result[collator.accountId] = collator.snapshot
        }

        let initResponse = ParachainStaking.DelegatorCollatorsResponse.empty
        return delegator.delegations.reduce(initResponse) { response, delegation in
            guard
                let collator = collatorsDict[delegation.owner],
                let minRewardableBond = collator.delegations.last?.amount else {
                let notElected = response.notElected.union([delegation.owner])
                return ParachainStaking.DelegatorCollatorsResponse(
                    pending: response.pending,
                    notElected: notElected
                )
            }

            guard !collator.delegations.contains(where: { $0.owner == accountId }) else {
                return response
            }

            let hasEnoughBond = (collator.delegations.count != maxRewardableDelegators) ||
                (delegator.total > minRewardableBond)

            let pendingCollator = ParachainStaking.DelegatorPendingCollator(
                bond: delegation,
                hasEnoughBond: hasEnoughBond
            )

            return ParachainStaking.DelegatorCollatorsResponse(
                pending: response.pending + [pendingCollator],
                notElected: response.notElected
            )
        }
    }
}

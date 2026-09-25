import Foundation

enum SubtensorRecommendationVerdict: Equatable {
    case verified(SubtensorPairVerification)
    case dropped(SubtensorRecommendationGate)
}

enum SubtensorRecommendationVerifier {
    static func chainQuery(for pairs: [SubtensorHotkeySubnet]) -> SubtensorValidatorChainQuery {
        var seenPairs: Set<SubtensorHotkeySubnet> = []

        return SubtensorValidatorChainQuery(
            pairs: pairs.filter { seenPairs.insert($0).inserted },
            includesHotkeyAlpha: false
        )
    }

    static func verify(
        _ pair: SubtensorHotkeySubnet,
        snapshot: SubtensorValidatorChainSnapshot,
        gates: SubtensorClientGates
    ) -> SubtensorRecommendationVerdict {
        guard let status = SubtensorValidatorChainStatus.make(snapshot: snapshot, pair: pair) else {
            return .dropped(.noCurrentUid)
        }

        let isSubnet = pair.netuid != SubtensorStakingPallet.rootNetuid

        if isSubnet, gates.requirePermit, status.hasPermit != true {
            return .dropped(.noPermit)
        }

        guard
            let take = snapshot.takes[pair.hotkey],
            !SubtensorTakeGate.exceedsMax(take: take, maxTake: gates.maxTake) else {
            return .dropped(.takeAboveMax)
        }

        if isSubnet, gates.requireActiveWithinCutoff, status.isActive != true {
            return .dropped(.inactive)
        }

        let verification = SubtensorPairVerification(
            uid: status.uid,
            take: Decimal(take) / Decimal(SubtensorStakingPallet.perU16Denominator),
            blocksSinceUpdate: status.blocksSinceUpdate
        )

        return .verified(verification)
    }
}

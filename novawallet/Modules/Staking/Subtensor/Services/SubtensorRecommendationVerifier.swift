import Foundation

enum SubtensorRecommendationVerifier {
    static func passesGates(
        _ pair: SubtensorHotkeySubnet,
        snapshot: SubtensorValidatorChainSnapshot,
        gates: SubtensorClientGates
    ) -> Bool {
        guard
            snapshot.uids[pair] != nil,
            let status = SubtensorValidatorChainStatus.make(snapshot: snapshot, pair: pair) else {
            return false
        }

        let isSubnet = pair.netuid != SubtensorPallet.rootNetuid

        if isSubnet, gates.requirePermit, status.hasPermit != true {
            return false
        }

        guard
            let take = snapshot.takes[pair.hotkey],
            !SubtensorTakeGate.exceedsMax(take: take, maxTake: gates.maxTake) else {
            return false
        }

        return !isSubnet || !gates.requireActiveWithinCutoff || status.isActive == true
    }
}

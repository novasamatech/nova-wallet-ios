import Foundation
import BigInt

struct SubtensorHotkeySubnet: Hashable {
    let hotkey: AccountId
    let netuid: UInt16
}

struct SubtensorValidatorChainQuery: Equatable {
    let pairs: [SubtensorHotkeySubnet]
    let includesHotkeyAlpha: Bool
}

struct SubtensorValidatorChainStatus: Equatable {
    let uid: UInt16
    let hasPermit: Bool?
    let blocksSinceUpdate: UInt64?
    let isActive: Bool?
}

struct SubtensorValidatorChainSnapshot {
    let blockHash: BlockHash
    let blockNumber: BlockNumber
    let uids: [SubtensorHotkeySubnet: UInt16]
    let permits: [UInt16: [Bool]]
    let lastUpdates: [UInt16: [UInt64]]
    let effectiveActivityCutoffs: [UInt16: UInt64]
    let takes: [AccountId: UInt16]
    let hotkeyAlpha: [SubtensorHotkeySubnet: Balance]
}

extension SubtensorValidatorChainStatus {
    static func effectiveActivityCutoff(factorMilli: UInt64, tempo: UInt64) -> UInt64 {
        let (product, didOverflow) = factorMilli.multipliedReportingOverflow(by: tempo)
        let saturatedProduct = didOverflow ? UInt64.max : product

        return max(1, saturatedProduct / 1000)
    }

    static func make(
        snapshot: SubtensorValidatorChainSnapshot,
        pair: SubtensorHotkeySubnet
    ) -> SubtensorValidatorChainStatus? {
        guard let uid = snapshot.uids[pair] else {
            return nil
        }

        guard pair.netuid != SubtensorStakingPallet.rootNetuid else {
            return SubtensorValidatorChainStatus(
                uid: uid,
                hasPermit: nil,
                blocksSinceUpdate: nil,
                isActive: nil
            )
        }

        let index = Int(uid)

        guard
            let permits = snapshot.permits[pair.netuid],
            index < permits.count,
            let lastUpdates = snapshot.lastUpdates[pair.netuid],
            index < lastUpdates.count,
            let cutoff = snapshot.effectiveActivityCutoffs[pair.netuid] else {
            return nil
        }

        let head = UInt64(snapshot.blockNumber)
        let lastUpdate = lastUpdates[index]
        let blocksSinceUpdate = head > lastUpdate ? head - lastUpdate : 0

        return SubtensorValidatorChainStatus(
            uid: uid,
            hasPermit: permits[index],
            blocksSinceUpdate: blocksSinceUpdate,
            isActive: blocksSinceUpdate <= cutoff
        )
    }
}

enum SubtensorTakeGate {
    static func exceedsMax(take: UInt16, maxTake: BigRational) -> Bool {
        let takeScaled = BigUInt(take) * maxTake.denominator
        let maxTakeScaled = BigUInt(SubtensorStakingPallet.perU16Denominator) * maxTake.numerator

        return takeScaled > maxTakeScaled
    }
}

struct SubtensorValidatorIdentity: Equatable {
    let name: String?
    let url: String?
    let githubRepo: String?
    let image: String?
    let discord: String?
    let description: String?
}

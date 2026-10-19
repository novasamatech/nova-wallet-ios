import Foundation
import BigInt

struct SubtensorHotkeySubnet: Hashable {
    let hotkey: AccountId
    let netuid: UInt16
}

struct SubtensorValidatorChainQuery: Equatable {
    let pairs: [SubtensorHotkeySubnet]
}

struct SubtensorValidatorChainStatus: Equatable {
    let hasPermit: Bool?
    let isActive: Bool?
}

struct SubtensorValidatorChainSnapshot {
    let blockNumber: BlockNumber
    let uids: [SubtensorHotkeySubnet: UInt16]
    let permits: [UInt16: [Bool]]
    let lastUpdates: [UInt16: [UInt64]]
    let effectiveActivityCutoffs: [UInt16: UInt64]
    let takes: [AccountId: UInt16]

    var takeFractions: [AccountId: Decimal] {
        takes.mapValues { Decimal($0) / Decimal(SubtensorPallet.perU16Denominator) }
    }
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

        guard pair.netuid != SubtensorPallet.rootNetuid else {
            return SubtensorValidatorChainStatus(hasPermit: nil, isActive: nil)
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

        return SubtensorValidatorChainStatus(hasPermit: permits[index], isActive: blocksSinceUpdate <= cutoff)
    }
}

enum SubtensorTakeGate {
    static func exceedsMax(take: UInt16, maxTake: BigRational) -> Bool {
        let takeScaled = BigUInt(take) * maxTake.denominator
        let maxTakeScaled = BigUInt(SubtensorPallet.perU16Denominator) * maxTake.numerator

        return takeScaled > maxTakeScaled
    }
}

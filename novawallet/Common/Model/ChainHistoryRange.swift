import Foundation

struct ChainHistoryRange {
    let currentEra: Staking.EraIndex
    let activeEra: Staking.EraIndex
    let historyDepth: UInt32

    var eraRange: Staking.EraRange {
        let start = currentEra >= historyDepth ? currentEra - historyDepth : 0
        let end = activeEra > 0 ? activeEra - 1 : 0
        return Staking.EraRange(start, end)
    }

    var eraList: [Staking.EraIndex] {
        let range = eraRange
        return Array(range.start ... range.end)
    }
}

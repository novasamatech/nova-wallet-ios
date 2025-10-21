import Foundation

final class BlockCountdownDisplay {
    let activeEra: Staking.EraIndex
    let blockTime: TimeInterval
    let createdAtDate: Date

    init(activeEra: Staking.EraIndex, blockTime: TimeInterval, createdAtDate: Date = Date()) {
        self.activeEra = activeEra
        self.blockTime = blockTime
        self.createdAtDate = createdAtDate
    }
}

extension BlockCountdownDisplay: EraCountdownDisplayProtocol {
    func timeIntervalTillStart(targetEra: Staking.EraIndex) -> TimeInterval {
        guard targetEra > activeEra else {
            return 0
        }

        let remainedTime = TimeInterval(targetEra - activeEra) * blockTime
        let elapsedTime = Date().timeIntervalSince(createdAtDate)

        return max(remainedTime - elapsedTime, 0)
    }

    func timeIntervalTillNextActiveEraStart() -> TimeInterval {
        timeIntervalTillStart(targetEra: activeEra + 1)
    }
}

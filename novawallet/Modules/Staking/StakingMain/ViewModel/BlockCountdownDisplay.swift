import Foundation

final class BlockCountdownDisplay {
    let activeEra: EraIndex
    let blockTime: BlockTime
    let createdAtDate: Date

    init(activeEra: EraIndex, blockTime: BlockTime, createdAtDate: Date = Date()) {
        self.activeEra = activeEra
        self.blockTime = blockTime
        self.createdAtDate = createdAtDate
    }
}

extension BlockCountdownDisplay: EraCountdownDisplayProtocol {
    func timeIntervalTillStart(targetEra: EraIndex) -> TimeInterval {
        guard targetEra > activeEra else {
            return 0
        }

        let remainedTime = TimeInterval(targetEra - activeEra) * blockTime.timeInterval
        let elapsedTime = Date().timeIntervalSince(createdAtDate)

        return max(remainedTime - elapsedTime, 0)
    }

    func timeIntervalTillNextActiveEraStart() -> TimeInterval {
        timeIntervalTillStart(targetEra: activeEra + 1)
    }
}

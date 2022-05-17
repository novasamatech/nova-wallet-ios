import Foundation

struct RoundCountdown {
    let roundInfo: ParachainStaking.RoundInfo
    let blockTime: TimeInterval
    let currentBlock: BlockNumber
    let createdAtDate: Date
}

extension RoundCountdown: EraCountdownDisplayProtocol {
    var activeEra: EraIndex { roundInfo.current }

    func timeIntervalTillStart(targetEra: EraIndex) -> TimeInterval {
        guard roundInfo.length > 0 else {
            return 0
        }

        let currentBlockNumber = max(roundInfo.first, currentBlock)

        let progressInRounds = (currentBlockNumber - roundInfo.first) / roundInfo.length

        guard roundInfo.current + progressInRounds < targetEra else {
            return 0
        }

        let remainedRounds = targetEra - (roundInfo.current + progressInRounds)
        let progressInBlocks = (currentBlockNumber - roundInfo.first) % roundInfo.length
        let roundProgress = TimeInterval(progressInBlocks) * blockTime

        return TimeInterval(remainedRounds * roundInfo.length) * blockTime - roundProgress
    }

    func timeIntervalTillNextActiveEraStart() -> TimeInterval {
        timeIntervalTillStart(targetEra: roundInfo.current + 1)
    }
}

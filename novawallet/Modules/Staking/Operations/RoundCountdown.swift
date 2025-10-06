import Foundation

struct RoundCountdown {
    let roundInfo: ParachainStaking.RoundInfo
    let blockTime: TimeInterval
    let currentBlock: BlockNumber
    let createdAtDate: Date
}

extension RoundCountdown: EraCountdownDisplayProtocol {
    var activeEra: Staking.EraIndex { roundInfo.current }

    func timeIntervalTillStart(targetEra: Staking.EraIndex) -> TimeInterval {
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

        let remainedTime = TimeInterval(remainedRounds * roundInfo.length) * blockTime - roundProgress
        let timerSpent = Date().timeIntervalSince(createdAtDate)

        return max(remainedTime - timerSpent, 0)
    }

    func timeIntervalTillNextActiveEraStart() -> TimeInterval {
        timeIntervalTillStart(targetEra: roundInfo.current + 1)
    }
}

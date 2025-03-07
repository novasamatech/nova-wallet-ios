import Foundation

struct ChainSessionInfo: Equatable {
    let offset: BlockNumber
    let length: SessionIndex
}

struct ChainSessionCountdown {
    let currentSession: SessionIndex
    let info: ChainSessionInfo
    let blockTime: TimeInterval
    let currentBlock: BlockNumber
    let createdAtDate: Date

    var currentSessionStart: BlockNumber {
        guard currentBlock >= info.offset else {
            return info.offset
        }

        let sessionProgress = (currentBlock - info.offset) % info.length

        return currentBlock - sessionProgress
    }
}

extension ChainSessionCountdown {
    func timeIntervalTillStart(targetSession: SessionIndex) -> TimeInterval {
        guard info.length > 0 else {
            return 0
        }

        let currentBlockNumber = max(currentSessionStart, currentBlock)

        let progressInSessions = (currentBlockNumber - currentSessionStart) / info.length

        guard currentSession + progressInSessions < targetSession else {
            return 0
        }

        let remainedSessions = targetSession - (currentSession + progressInSessions)
        let progressInBlocks = (currentBlockNumber - currentSessionStart) % info.length
        let sessionProgress = TimeInterval(progressInBlocks) * blockTime

        let remainedTime = TimeInterval(remainedSessions * info.length) * blockTime - sessionProgress
        let timerSpent = Date().timeIntervalSince(createdAtDate)

        return max(remainedTime - timerSpent, 0)
    }

    func timeIntervalTillNextSessionStart() -> TimeInterval {
        timeIntervalTillStart(targetSession: currentSession + 1)
    }
}

import Foundation

enum BlockTimestampEstimator {
    static func estimateTimestamp(
        for block: BlockNumber,
        currentBlock: BlockNumber,
        blockTimeInMillis: UInt64
    ) -> UInt64 {
        let currentTimestamp = UInt64(Date().timeIntervalSince1970)

        guard currentBlock > block else {
            return currentTimestamp
        }

        let elapsedSeconds = (UInt64(currentBlock - block) * blockTimeInMillis).millisecondsToSeconds

        guard currentTimestamp > elapsedSeconds else {
            return 0
        }

        return currentTimestamp - elapsedSeconds
    }
}

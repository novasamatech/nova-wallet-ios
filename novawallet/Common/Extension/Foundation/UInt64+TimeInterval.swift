import Foundation

extension UInt64 {
    var timeInterval: TimeInterval {
        let fullSeconds = self / 1000
        let milliseconds = TimeInterval(self % 1000) / 1000.0

        return TimeInterval(fullSeconds) + milliseconds
    }

    var millisecondsToSeconds: UInt64 {
        self / 1000
    }
}

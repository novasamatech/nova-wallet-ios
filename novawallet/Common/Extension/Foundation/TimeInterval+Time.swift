import Foundation

extension TimeInterval {
    static let secondsInHour: TimeInterval = 3600
    static let secondsInMinute: TimeInterval = 60.0
    static let secondsInDay: TimeInterval = 24 * secondsInHour

    var milliseconds: Int {
        let multiplier: Int = 1000
        let seconds = Int(self)
        let milliseconds = (self - TimeInterval(seconds)) * TimeInterval(multiplier)

        return seconds * multiplier + Int(milliseconds)
    }

    var seconds: TimeInterval { self / 1000 }
    var minutesFromSeconds: Int { Int(self / Self.secondsInMinute) }
    var daysFromSeconds: Int { Int(self / Self.secondsInDay) }
    var secondsFromDays: TimeInterval { self * Self.secondsInDay }
    var hoursFromSeconds: Int { Int(self / Self.secondsInHour) }
    var intervalsInDay: Int { self > 0.0 ? Int(Self.secondsInDay / self) : 0 }
}

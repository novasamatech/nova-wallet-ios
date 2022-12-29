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
    var secondsFromMinutes: TimeInterval { self * Self.secondsInMinute }
    var daysFromSeconds: Int { Int(self / Self.secondsInDay) }
    var fractionDaysFromSeconds: Decimal { Decimal(self) / Decimal(Self.secondsInDay) }
    var secondsFromDays: TimeInterval { self * Self.secondsInDay }
    var hoursFromSeconds: Int { Int(self / Self.secondsInHour) }
    var secondsFromHours: TimeInterval { self * Self.secondsInHour }
    var intervalsInDay: Int { self > 0.0 ? Int(Self.secondsInDay / self) : 0 }

    func roundingUpToHour() -> TimeInterval {
        let inMillis = milliseconds
        let hourInMillis = Self.secondsInHour.milliseconds

        guard inMillis % hourInMillis != 0 else {
            return UInt64(inMillis).timeInterval
        }

        let nextHour = (inMillis / hourInMillis) * hourInMillis + hourInMillis

        return UInt64(nextHour).timeInterval
    }
}

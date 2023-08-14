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

    func getDaysAndHours(roundingDown: Bool) -> (Int, Int) {
        let days = daysFromSeconds
        let hours = (self - TimeInterval(days).secondsFromDays).hoursFromSeconds

        if !roundingDown {
            return roundUp(days: days, hours: hours)
        } else {
            return (days, hours)
        }
    }

    private func roundUp(days: Int, hours: Int) -> (Int, Int) {
        let diff = self - TimeInterval(days).secondsFromDays - TimeInterval(hours).secondsFromHours
        let remainedMinutes = diff.minutesFromSeconds

        guard remainedMinutes > TimeInterval.secondsInHour.minutesFromSeconds / 2 else {
            return (days, hours)
        }

        guard TimeInterval(hours + 1).secondsFromHours.daysFromSeconds == 0 else {
            return (days + 1, 0)
        }

        return (days, hours + 1)
    }
}

import Foundation

extension Calendar {
    func endOfDay(for date: Date) -> Date? {
        guard let interval = dateInterval(of: .day, for: date) else {
            return nil
        }
        return interval.end.addingTimeInterval(-1)
    }
}

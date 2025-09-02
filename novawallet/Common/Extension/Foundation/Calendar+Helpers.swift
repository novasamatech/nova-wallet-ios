import Foundation

extension Calendar {
    func endOfDay(for date: Date) -> Date? {
        guard let interval = dateInterval(of: .day, for: date) else {
            return nil
        }
        return interval.end.addingTimeInterval(-1)
    }
}

extension Date {
    func sameYear(as date: Date) -> Bool {
        let currentYear = Calendar.current.component(.year, from: self)
        let dateYear = Calendar.current.component(.year, from: date)

        return currentYear == dateYear
    }
}

import Foundation

extension StakingRewardFiltersViewController {
    enum Section: Hashable {
        case period
        case start(date: String, active: Bool)
        case endAlwaysToday
        case end(date: String, active: Bool)
    }

    enum Row: Hashable {
        case selectable(title: String, selected: Bool)
        case dateAlwaysToday(String, Bool)
        case calendar(CalendarIdentifier, date: Date?, minDate: Date?, maxDate: Date?)
    }

    enum CalendarIdentifier: String {
        case startDate
        case endDate
    }
}
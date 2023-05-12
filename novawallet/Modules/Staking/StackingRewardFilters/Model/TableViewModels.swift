import Foundation

extension StackingRewardFiltersViewController {
    enum Section: Hashable {
        case period
        case start(String)
        case endAlwaysToday
        case end(String)
    }

    enum Row: Hashable {
        case selectable(title: String, selected: Bool)
        case dateAlwaysToday(String, Bool)
        case calendar(CalendarIdentifier, Date?)
    }

    enum CalendarIdentifier: String {
        case startDate
        case endDate
    }
}

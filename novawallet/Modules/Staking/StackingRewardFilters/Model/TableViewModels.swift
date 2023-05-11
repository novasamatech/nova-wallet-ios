import Foundation

extension StackingRewardFiltersViewController {
    enum Section: Int, Hashable {
        case period
        case start
        case endAlwaysToday
        case end
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

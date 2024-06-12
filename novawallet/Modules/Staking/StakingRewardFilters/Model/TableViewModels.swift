import Foundation
import Operation_iOS

extension StakingRewardFiltersViewController {
    enum Section: Identifiable, Equatable {
        case period
        case start(date: String, active: Bool)
        case endAlwaysToday
        case end(date: String, active: Bool)

        var identifier: String {
            switch self {
            case .period:
                return "period"
            case .start:
                return Self.startDateIdentifier
            case .endAlwaysToday:
                return Self.endAlwaysTodayIdentifier
            case .end:
                return Self.endDateIdentifier
            }
        }

        static var startDateIdentifier: String {
            "start"
        }

        static var endAlwaysTodayIdentifier: String {
            "endAlwaysToday"
        }

        static var endDateIdentifier: String {
            "end"
        }
    }

    enum Row: Identifiable, Equatable {
        case selectable(title: String, selected: Bool)
        case dateAlwaysToday(String, Bool)
        case calendar(CalendarIdentifier, date: Date?, minDate: Date?, maxDate: Date?)

        var identifier: String {
            switch self {
            case let .selectable(title, _):
                return "selectable-\(title)"
            case .dateAlwaysToday:
                return "dateAlwaysToday"
            case let .calendar(id, _, _, _):
                return "calendar-\(id)"
            }
        }
    }

    enum CalendarIdentifier: String {
        case startDate
        case endDate
    }
}

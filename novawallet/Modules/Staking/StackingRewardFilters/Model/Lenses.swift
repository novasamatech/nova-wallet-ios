import Foundation

struct GenericLens<Whole, Part> {
    let get: (Whole) -> Part
    let set: (Part, Whole) -> Whole
}

extension StackingRewardFiltersViewController {
    enum Lens {
        static let startDayCollapsed = GenericLens<StackingRewardFiltersViewModel.CustomPeriod, Bool>(
            get: { $0.startDay.isCollapsed },
            set: { .init(
                startDay: .init(value: $1.startDay.value, isCollapsed: $0),
                endDay: $1.endDay
            )
            }
        )

        static let endDayCollapsed = GenericLens<StackingRewardFiltersViewModel.CustomPeriod, Bool>(
            get: { $0.endDay.isCollapsed },
            set: { .init(
                startDay: $1.startDay,
                endDay: .init(value: $1.endDay.value, isCollapsed: $0)
            )
            }
        )

        static let endDayValue = GenericLens<StackingRewardFiltersViewModel.CustomPeriod, StackingRewardFiltersViewModel.EndDayValue?>(
            get: { $0.endDay.value },
            set: { .init(
                startDay: $1.startDay,
                endDay: .init(value: $0, isCollapsed: $1.endDay.isCollapsed)
            )
            }
        )

        static let endDayDate = GenericLens<StackingRewardFiltersViewModel.EndDayValue, Date?>(
            get: {
                switch $0 {
                case .alwaysToday:
                    return nil
                case let .exact(exactDate):
                    return exactDate
                }
            },
            set: {
                switch $1 {
                case .alwaysToday:
                    return .alwaysToday
                case .exact:
                    return .exact($0)
                }
            }
        )
    }
}

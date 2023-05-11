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
            get: { $0.endDay.collapsed },
            set: { .init(
                startDay: $1.startDay,
                endDay: .init(value: $1.endDay.value, collapsed: $0)
            )
            }
        )

        static let startDayValue =
            GenericLens<StackingRewardFiltersViewModel.CustomPeriod, Date?>(
                get: { $0.startDay.value },
                set: { .init(
                    startDay: .init(value: $0, isCollapsed: $1.startDay.isCollapsed),
                    endDay: $1.endDay
                )
                }
            )

        static let endDayValue =
            GenericLens<StackingRewardFiltersViewModel.CustomPeriod, StackingRewardFiltersViewModel.EndDayValue?>(
                get: { $0.endDay.value },
                set: { .init(
                    startDay: $1.startDay,
                    endDay: .init(value: $0, collapsed: $1.endDay.collapsed)
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

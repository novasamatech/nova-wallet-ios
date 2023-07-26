import Foundation

extension StakingRewardFiltersViewController {
    enum Lens {
        static let startDayValue =
            GenericLens<StakingRewardFiltersViewModel.CustomPeriod, Date?>(
                get: { $0.startDay.value },
                set: { .init(
                    startDay: .init(value: $0, collapsed: $1.startDay.collapsed),
                    endDay: $1.endDay
                )
                }
            )

        static let endDayValue =
            GenericLens<StakingRewardFiltersViewModel.CustomPeriod, StakingRewardFiltersViewModel.EndDayValue?>(
                get: { $0.endDay.value },
                set: { .init(
                    startDay: $1.startDay,
                    endDay: .init(value: $0, collapsed: $1.endDay.collapsed)
                )
                }
            )

        static let endDayDate = GenericLens<StakingRewardFiltersViewModel.EndDayValue, Date?>(
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

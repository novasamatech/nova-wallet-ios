import Foundation

enum SubtensorPriceChartSelection: Equatable {
    case point(sourceIndex: Int)
    case noData(date: Date)
}

struct SubtensorPriceChartViewModel: Equatable {
    struct Point: Equatable {
        let sourceIndex: Int
        let date: Date
        let value: Decimal

        var plotValue: Double {
            NSDecimalNumber(decimal: value).doubleValue
        }
    }

    struct DatedSeries: Equatable {
        let points: [Point]
        let range: ClosedRange<Date>
        let predecessor: Point?
        let coverageTolerance: TimeInterval

        var hasMissingPrefix: Bool {
            guard predecessor == nil, let first = points.first else {
                return false
            }

            return first.date.timeIntervalSince(range.lowerBound) > coverageTolerance
        }
    }

    enum Series: Equatable {
        case indexed([Double])
        case dated(DatedSeries)
    }

    let series: Series
    let axisLabels: [String]
    let isRising: Bool
}

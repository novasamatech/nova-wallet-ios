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

        var hasMissingPrefix: Bool {
            predecessor == nil && points.first.map { $0.date > range.lowerBound } == true
        }
    }

    enum Series: Equatable {
        case indexed([Double])
        case dated(DatedSeries)
    }

    let series: Series
    let axisLabels: [String]
    let isRising: Bool

    init(values: [Double], axisLabels: [String], isRising: Bool) {
        series = .indexed(values)
        self.axisLabels = axisLabels
        self.isRising = isRising
    }

    init(datedSeries: DatedSeries, axisLabels: [String], isRising: Bool) {
        series = .dated(datedSeries)
        self.axisLabels = axisLabels
        self.isRising = isRising
    }
}

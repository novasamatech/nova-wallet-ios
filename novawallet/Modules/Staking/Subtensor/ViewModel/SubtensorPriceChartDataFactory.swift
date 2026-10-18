import Foundation

struct SubtensorPriceChartData {
    struct Entry: Equatable {
        let coordinate: Double
        let value: Double
        let sourceIndex: Int?
    }

    let entries: [Entry]
    let xRange: ClosedRange<Double>
    let yRange: ClosedRange<Double>
    let coverageStart: Double?

    func selection(at coordinate: Double) -> SubtensorPriceChartSelection? {
        guard coordinate.isFinite else {
            return nil
        }

        let position = min(max(coordinate, xRange.lowerBound), xRange.upperBound)

        if let coverageStart, position < coverageStart {
            return .noData(date: Date(timeIntervalSince1970: position))
        }

        return entries.filter { $0.sourceIndex != nil }
            .min { abs($0.coordinate - position) < abs($1.coordinate - position) }
            .flatMap(\.sourceIndex)
            .map { .point(sourceIndex: $0) }
    }
}

enum SubtensorPriceChartDataFactory {
    static func create(
        series: SubtensorPriceChartViewModel.Series,
        availablePoints: Int
    ) -> SubtensorPriceChartData? {
        switch series {
        case let .indexed(values):
            return createIndexed(values, availablePoints: availablePoints)
        case let .dated(series):
            return createDated(series, availablePoints: availablePoints)
        }
    }
}

private extension SubtensorPriceChartDataFactory {
    enum Constants {
        static let flatRangeFactor: Double = 0.02
        static let minimumSpread: Double = 1e-6
    }

    static func yRange(values: [Double]) -> ClosedRange<Double>? {
        guard let minimum = values.min(), let maximum = values.max() else {
            return nil
        }

        let padding = maximum > minimum ? 0 : max(abs(maximum) * Constants.flatRangeFactor, Constants.minimumSpread)
        return (minimum - padding) ... (maximum + padding)
    }

    static func sampled<T>(_ points: [T], availablePoints: Int) -> [T] {
        availablePoints > 0 ? points.optimizedForChart(availablePoints: max(2, availablePoints)) : points
    }

    static func createIndexed(_ values: [Double], availablePoints: Int) -> SubtensorPriceChartData? {
        let entries = values.enumerated().filter(\.element.isFinite).map { index, value in
            SubtensorPriceChartData.Entry(coordinate: Double(index), value: value, sourceIndex: index)
        }

        guard entries.count > 1, let first = entries.first, let last = entries.last,
              let bounds = yRange(values: entries.map(\.value)) else {
            return nil
        }

        return SubtensorPriceChartData(
            entries: sampled(entries, availablePoints: availablePoints),
            xRange: first.coordinate ... last.coordinate,
            yRange: bounds,
            coverageStart: nil
        )
    }

    static func createDated(
        _ series: SubtensorPriceChartViewModel.DatedSeries,
        availablePoints: Int
    ) -> SubtensorPriceChartData? {
        guard series.points.count > 1, let first = series.points.first else {
            return nil
        }

        let start = series.range.lowerBound.timeIntervalSince1970
        let end = series.range.upperBound.timeIntervalSince1970
        var values = series.points.map(\.plotValue)
        var prefix: [SubtensorPriceChartData.Entry] = []

        if let predecessor = series.predecessor {
            values.append(predecessor.plotValue)
            prefix = [entry(for: predecessor, selectable: false)]
        } else if series.hasMissingPrefix {
            values.append(0)
            // Keep the boundary outside downsampling so missing history never becomes a ramp.
            prefix = [
                .init(coordinate: start, value: 0, sourceIndex: nil),
                .init(coordinate: first.date.timeIntervalSince1970, value: 0, sourceIndex: nil)
            ]
        }

        guard let bounds = yRange(values: values) else {
            return nil
        }

        let entries = sampled(series.points, availablePoints: availablePoints).map { entry(for: $0) }
        let coverageStart = series.hasMissingPrefix ? first.date.timeIntervalSince1970 : start

        return SubtensorPriceChartData(
            entries: prefix + entries,
            xRange: start ... end,
            yRange: bounds,
            coverageStart: coverageStart
        )
    }

    static func entry(
        for point: SubtensorPriceChartViewModel.Point,
        selectable: Bool = true
    ) -> SubtensorPriceChartData.Entry {
        SubtensorPriceChartData.Entry(
            coordinate: point.date.timeIntervalSince1970,
            value: point.plotValue,
            sourceIndex: selectable ? point.sourceIndex : nil
        )
    }
}

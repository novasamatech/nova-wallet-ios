import Foundation

struct SubtensorRate: Equatable {
    enum Source: Equatable {
        case chainNetworkAverage(isNetOfTake: Bool)
        case config
    }

    let annualRate: Decimal
    let source: Source
}

struct SubtensorReportedYield: Equatable {
    static let reportedRateScale: Decimal = 100

    let reportedRate: String
    let stamp: SubtensorBackendStamp

    var annualRate: Decimal? {
        guard
            stamp.freshness == .fresh,
            isNonNegative,
            let reportedValue = try? BittensorApiDecimal.decimal(reportedRate) else {
            return nil
        }

        return reportedValue / Self.reportedRateScale
    }
}

private extension SubtensorReportedYield {
    var isNonNegative: Bool {
        (try? BittensorApiDecimal.fraction(reportedRate)) != nil
    }
}

struct SubtensorAlphaYields: Equatable {
    let netuid: UInt16
    let yields: [AccountId: SubtensorReportedYield]
    let stamp: SubtensorBackendStamp
    let isTruncated: Bool
}

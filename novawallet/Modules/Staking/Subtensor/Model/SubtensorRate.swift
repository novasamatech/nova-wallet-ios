import Foundation

struct SubtensorReportedYield: Equatable {
    static let reportedRateScale: Decimal = 100

    let reportedRate: String
    let stamp: SubtensorBackendStamp
    /// False when the backend marked the rate unreliable, for example a dust nominated stake
    /// compounded into hundreds of thousands of percent; such a rate is never shown or ranked.
    let isReliable: Bool

    init(reportedRate: String, stamp: SubtensorBackendStamp, isReliable: Bool = true) {
        self.reportedRate = reportedRate
        self.stamp = stamp
        self.isReliable = isReliable
    }

    var annualRate: Decimal? {
        guard
            isReliable,
            stamp.freshness == .fresh,
            let reportedValue = try? BittensorApiDecimal.decimal(reportedRate),
            reportedValue >= 0 else {
            return nil
        }

        return reportedValue / Self.reportedRateScale
    }
}

struct SubtensorAlphaYields: Equatable {
    let netuid: UInt16
    let yields: [AccountId: SubtensorReportedYield]
    let stamp: SubtensorBackendStamp
}

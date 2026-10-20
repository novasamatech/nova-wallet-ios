import Foundation

struct SubtensorReportedYield: Equatable {
    static let reportedRateScale: Decimal = 100

    let reportedRate: String
    let stamp: SubtensorBackendStamp
    var isReliable = true

    var annualRate: Decimal? {
        isReliable ? annualRateIgnoringReliability : nil
    }

    var annualRateIgnoringReliability: Decimal? {
        guard
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

extension SubtensorAlphaYields {
    func droppingUnreliable() -> SubtensorAlphaYields {
        SubtensorAlphaYields(netuid: netuid, yields: yields.filter(\.value.isReliable), stamp: stamp)
    }
}

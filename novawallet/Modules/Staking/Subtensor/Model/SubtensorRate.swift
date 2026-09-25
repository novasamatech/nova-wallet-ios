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
    let reportedRate: String
    let stamp: SubtensorBackendStamp
}

struct SubtensorAlphaYields: Equatable {
    let netuid: UInt16
    let yields: [AccountId: SubtensorReportedYield]
    let stamp: SubtensorBackendStamp
    let isTruncated: Bool
}

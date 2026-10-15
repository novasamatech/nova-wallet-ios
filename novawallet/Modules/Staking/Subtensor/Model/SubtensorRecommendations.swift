import Foundation

struct SubtensorMetricScore: Equatable {
    let raw: Decimal?
    let normalized: Decimal
}

struct SubtensorRecommendationGeneration: Equatable {
    let sourceBlockNumber: UInt64
    let carriedOverNetuids: [UInt16]
    let stamp: SubtensorBackendStamp
}

struct SubtensorClientGates: Equatable {
    let maxTake: BigRational
    let requirePermit: Bool
    let requireActiveWithinCutoff: Bool
}

struct SubtensorRecommendedValidator: Equatable {
    let hotkey: AccountId
    let name: String?
}

struct SubtensorRecommendedValidators: Equatable {
    let generation: SubtensorRecommendationGeneration
    let validators: [SubtensorRecommendedValidator]
}

struct SubtensorRankedSubnet: Equatable {
    let netuid: UInt16
    let taoIn: Decimal?
    let volatility: SubtensorMetricScore?
    let ageBlocks: UInt64?
}

struct SubtensorRankedSubnets: Equatable {
    let generation: SubtensorRecommendationGeneration
    let items: [SubtensorRankedSubnet]
}

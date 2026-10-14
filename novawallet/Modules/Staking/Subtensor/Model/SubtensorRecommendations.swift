import Foundation

enum SubtensorRecommendationClass: String, Equatable {
    case stable
    case balanced
    case higherUpside
}

struct SubtensorMetricScore: Equatable {
    let raw: Decimal?
    let normalized: Decimal
}

struct SubtensorRecommendationGeneration: Equatable {
    let sourceBlockNumber: UInt64
    let receivedAt: TimeInterval
    let carriedOverNetuids: [UInt16]
    let stamp: SubtensorBackendStamp
}

struct SubtensorClientGates: Equatable {
    let maxTake: BigRational
    let requirePermit: Bool
    let requireActiveWithinCutoff: Bool
}

struct SubtensorVerifiedRecommendations: Equatable {
    let generation: SubtensorRecommendationGeneration
    let clientGates: SubtensorClientGates
    let classes: [SubtensorRecommendationClass: [SubtensorHotkeySubnet]]
}

struct SubtensorRankedSubnet: Equatable {
    enum Status: Equatable {
        case scored
        case gated
        case unavailable
    }

    let netuid: UInt16
    let status: Status
    let taoIn: Decimal?
    let volatility: SubtensorMetricScore?
    let ageBlocks: UInt64?
    let scoredValidators: Int
}

struct SubtensorRankedSubnets: Equatable {
    let generation: SubtensorRecommendationGeneration
    let items: [SubtensorRankedSubnet]
}

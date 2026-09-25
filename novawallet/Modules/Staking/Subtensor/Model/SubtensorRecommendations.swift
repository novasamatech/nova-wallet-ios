import Foundation

enum SubtensorRecommendationClass: String, Equatable {
    case stable
    case balanced
    case higherUpside
    case aboveThreshold
}

enum SubtensorRecommendationGate: Hashable {
    case noCurrentUid
    case noPermit
    case takeAboveMax
    case inactive
}

struct SubtensorMetricScore: Equatable {
    let raw: Decimal?
    let normalized: Decimal
    let weight: Decimal
    let isDerived: Bool
    let flags: [String]
}

struct SubtensorRecommendationBreakdown: Equatable {
    let volatility: SubtensorMetricScore?
    let maxDrawdown: SubtensorMetricScore?
    let poolDepth: SubtensorMetricScore?
    let age: SubtensorMetricScore?
    let emissionStability: SubtensorMetricScore?
    let stakeConcentration: SubtensorMetricScore?
    let permitMargin: SubtensorMetricScore?
    let rootStakeMargin: SubtensorMetricScore?
    let vtrust: SubtensorMetricScore
}

struct SubtensorSubnetBreakdown: Equatable {
    let volatility: SubtensorMetricScore
    let maxDrawdown: SubtensorMetricScore
    let poolDepth: SubtensorMetricScore
    let age: SubtensorMetricScore
    let emissionStability: SubtensorMetricScore
    let stakeConcentration: SubtensorMetricScore
}

struct SubtensorPairVerification: Equatable {
    let uid: UInt16
    let take: Decimal
    let blocksSinceUpdate: UInt64?
}

struct SubtensorRecommendedPair: Equatable {
    let netuid: UInt16
    let hotkey: AccountId
    let subnetName: String
    let symbol: String
    let validatorName: String?
    let score: Decimal
    let subnetRisk: Decimal?
    let validatorRisk: Decimal
    let breakdown: SubtensorRecommendationBreakdown
    let effectiveStakeAlpha: Decimal
    let rootStakeTao: Decimal
    let priceTao: Decimal?
    let flags: [String]
    let verification: SubtensorPairVerification
}

struct SubtensorRecommendationGeneration: Equatable {
    let id: String
    let sourceBlockNumber: UInt64
    let modelVersion: String
    let ageSeconds: Int64
    let receivedAt: TimeInterval
    let isServedFromMemory: Bool
    let excludedNetuids: [UInt16]
    let carriedOverNetuids: [UInt16]
    let inputFlags: [String]
    let stamp: SubtensorBackendStamp
    let isPartial: Bool
}

struct SubtensorClientGates: Equatable {
    let maxTake: BigRational
    let requirePermit: Bool
    let requireActiveWithinCutoff: Bool
}

extension SubtensorClientGates {
    static let backendDefault = SubtensorClientGates(
        maxTake: BigRational(numerator: 18, denominator: 100),
        requirePermit: true,
        requireActiveWithinCutoff: true
    )
}

struct SubtensorVerifiedRecommendations: Equatable {
    let generation: SubtensorRecommendationGeneration
    let clientGates: SubtensorClientGates
    let topN: Int
    let classes: [SubtensorRecommendationClass: [SubtensorRecommendedPair]]
    let droppedByGate: [SubtensorRecommendationGate: Int]
    let verifiedAtBlock: BlockNumber
}

struct SubtensorRankedSubnet: Equatable {
    enum Status: Equatable {
        case scored
        case gated
        case unavailable
    }

    let netuid: UInt16
    let subnetName: String
    let symbol: String
    let status: Status
    let isEligible: Bool
    let reasons: [String]
    let riskClass: SubtensorRecommendationClass?
    let subnetRisk: Decimal?
    let breakdown: SubtensorSubnetBreakdown?
    let taoIn: Decimal?
    let priceTao: Decimal?
    let ageBlocks: UInt64?
    let scoredValidators: Int
    let eligibleValidators: Int
    let flags: [String]
}

struct SubtensorRecommendationPolicy: Equatable {
    enum Classification: Equatable {
        case pair
        case subnet
    }

    enum HistoryPolicy: Equatable {
        case neutral
        case exclude
    }

    let classification: Classification
    let requiresIdentity: Bool
    let requiresPositiveSignal: Bool
    let insufficientHistory: HistoryPolicy
}

struct SubtensorRankedSubnets: Equatable {
    let generation: SubtensorRecommendationGeneration
    let policy: SubtensorRecommendationPolicy
    let items: [SubtensorRankedSubnet]
}

import Foundation

extension BittensorApi {
    enum RankingStatus: String, Decodable, Equatable {
        case scored = "SCORED"
        case gated = "GATED"
        case unavailable = "UNAVAILABLE"
    }

    enum RankedClass: String, Decodable, Equatable {
        case stable
        case balanced
        case higherUpside
        case aboveThreshold
    }

    struct SubnetRankingCollection: Decodable, Equatable {
        let meta: RecommendationMetadata
        let items: [SubnetRanking]
    }

    struct SubnetRanking: Decodable, Equatable {
        let netuid: UInt16
        let status: RankingStatus
        let breakdown: SubnetBreakdown?
        let taoIn: String?
        let ageBlocks: UInt64?
        let validators: SubnetValidatorCounts
    }

    struct SubnetBreakdown: Decodable, Equatable {
        let volatility: MetricScore
    }

    struct SubnetValidatorCounts: Decodable, Equatable {
        let scored: UInt64
    }

    struct RankedValidatorCollection: Decodable, Equatable {
        let meta: RecommendationMetadata
        let items: [RankedValidator]
    }

    struct RankedValidator: Decodable, Equatable {
        let netuid: UInt16
        let hotkey: String
        let validatorName: String?
        let recommendationClass: RankedClass
        let eligible: Bool
        let clientChecks: [ClientCheck]
    }
}

extension BittensorApi.SubnetRankingCollection: BittensorApiGenerationalResponse {
    var generationOrder: BittensorApiGenerationOrder {
        BittensorApiGenerationOrder(
            asOf: meta.components.recommendations.asOf,
            sourceBlockNumber: meta.generation.sourceBlockNumber
        )
    }
}

extension BittensorApi.RankedValidatorCollection: BittensorApiGenerationalResponse {
    var generationOrder: BittensorApiGenerationOrder {
        BittensorApiGenerationOrder(
            asOf: meta.components.recommendations.asOf,
            sourceBlockNumber: meta.generation.sourceBlockNumber
        )
    }
}

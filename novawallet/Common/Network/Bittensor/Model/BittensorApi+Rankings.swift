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

    enum Classification: String, Decodable, Equatable {
        case pair = "PAIR"
        case subnet = "SUBNET"
    }

    enum HistoryPolicy: String, Decodable, Equatable {
        case neutral = "NEUTRAL"
        case exclude = "EXCLUDE"
    }

    struct SubnetRankingCollection: Decodable, Equatable {
        let meta: ViewMetadata
        let items: [SubnetRanking]
    }

    struct ViewMetadata: Decodable, Equatable {
        let completeness: Completeness
        let components: RecommendationMetadata.Components
        let generation: Generation
        let clientGates: ClientGates
        let policy: Policy
    }

    struct Policy: Decodable, Equatable {
        let classification: Classification
        let requireIdentity: Bool
        let requirePositiveSignal: Bool
        let insufficientHistory: HistoryPolicy
    }

    struct SubnetRanking: Decodable, Equatable {
        let netuid: UInt16
        let subnetName: String
        let symbol: String
        let status: RankingStatus
        let eligible: Bool
        let reasons: [String]
        let riskClass: RankedClass?
        let subnetRisk: String?
        let breakdown: SubnetBreakdown?
        let taoIn: String?
        let priceTao: String?
        let ageBlocks: UInt64?
        let validators: SubnetValidatorCounts
        let flags: [String]
    }

    struct SubnetBreakdown: Decodable, Equatable {
        let volatility: MetricScore
        let maxDrawdown: MetricScore
        let poolDepth: MetricScore
        let age: MetricScore
        let emissionStability: MetricScore
        let stakeConcentration: MetricScore
    }

    struct SubnetValidatorCounts: Decodable, Equatable {
        let scored: UInt64
        let eligible: UInt64
    }
}

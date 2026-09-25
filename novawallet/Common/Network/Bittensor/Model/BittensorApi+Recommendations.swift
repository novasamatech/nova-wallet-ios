import Foundation

extension BittensorApi {
    enum ServedFrom: String, Decodable, Equatable {
        case redis = "REDIS"
        case memory = "MEMORY"
    }

    enum ClientCheck: String, Decodable, Equatable {
        case uid
        case validatorPermit = "validator_permit"
        case take
        case lastUpdate = "last_update"
    }

    struct RecommendationCollection: Decodable, Equatable {
        let meta: RecommendationMetadata
        let classes: RecommendationClasses
    }

    struct RecommendationMetadata: Decodable, Equatable {
        struct Components: Decodable, Equatable {
            let recommendations: AvailableComponent
        }

        let completeness: Completeness
        let components: Components
        let generation: Generation
        let clientGates: ClientGates
        let topN: Int
        let counts: ClassCounts
    }

    struct Generation: Decodable, Equatable {
        let id: String
        let sourceBlockNumber: UInt64
        let modelVersion: String
        let ageSeconds: UInt64
        let servedFrom: ServedFrom
        let excludedNetuids: [UInt16]
        let carriedOverNetuids: [UInt16]
        let inputFlags: [String]
    }

    struct ClientGates: Decodable, Equatable {
        let maxTake: String
        let requirePermit: Bool
        let requireActiveWithinCutoff: Bool
    }

    struct ClassCounts: Decodable, Equatable {
        let stable: UInt64
        let balanced: UInt64
        let higherUpside: UInt64
        let excluded: UInt64
    }

    struct RecommendationClasses: Decodable, Equatable {
        let stable: [Recommendation]
        let balanced: [Recommendation]
        let higherUpside: [Recommendation]
    }

    struct Recommendation: Decodable, Equatable {
        let netuid: UInt16
        let subnetName: String
        let symbol: String
        let uid: UInt16
        let hotkey: String
        let coldkey: String
        let validatorName: String?
        let score: String
        let subnetRisk: String?
        let validatorRisk: String
        let breakdown: RecommendationBreakdown
        let effectiveStakeAlpha: String
        let rootStakeTao: String
        let vtrust: String
        let priceTao: String?
        let flags: [String]
        let clientChecks: [ClientCheck]
    }

    struct RecommendationBreakdown: Decodable, Equatable {
        let volatility: MetricScore?
        let maxDrawdown: MetricScore?
        let poolDepth: MetricScore?
        let age: MetricScore?
        let emissionStability: MetricScore?
        let stakeConcentration: MetricScore?
        let permitMargin: MetricScore?
        let rootStakeMargin: MetricScore?
        let vtrust: MetricScore
    }

    struct MetricScore: Decodable, Equatable {
        let raw: String?
        let normalized: String
        let weight: String
        let source: ValueQuality
        let flags: [String]
    }
}

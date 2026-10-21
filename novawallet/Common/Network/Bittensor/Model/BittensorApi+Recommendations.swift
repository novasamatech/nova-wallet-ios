import Foundation

extension BittensorApi {
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

        let components: Components
        let generation: Generation
        let clientGates: ClientGates
    }

    struct Generation: Decodable, Equatable {
        let sourceBlockNumber: UInt64
        let carriedOverNetuids: [UInt16]
    }

    struct ClientGates: Decodable, Equatable {
        let maxTake: String
        let requirePermit: Bool
        let requireActiveWithinCutoff: Bool
    }

    struct RecommendationClasses: Decodable, Equatable {
        let stable: [Recommendation]
        let balanced: [Recommendation]
        let higherUpside: [Recommendation]
    }

    struct Recommendation: Decodable, Equatable {
        let netuid: UInt16
        let hotkey: String
        let clientChecks: [ClientCheck]
    }

    struct MetricScore: Decodable, Equatable {
        let raw: String?
        let normalized: String
    }
}

extension BittensorApi.RecommendationCollection: BittensorApiGenerationalResponse {
    var generationOrder: BittensorApiGenerationOrder {
        BittensorApiGenerationOrder(
            asOf: meta.components.recommendations.asOf,
            sourceBlockNumber: meta.generation.sourceBlockNumber
        )
    }
}

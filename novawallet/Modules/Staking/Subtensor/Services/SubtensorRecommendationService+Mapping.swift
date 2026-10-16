import Foundation

extension SubtensorRecommendationService {
    static func clientGates(_ gates: BittensorApi.ClientGates) throws -> SubtensorClientGates {
        try SubtensorClientGates(
            maxTake: BittensorApiDecimal.fraction(gates.maxTake),
            requirePermit: gates.requirePermit,
            requireActiveWithinCutoff: gates.requireActiveWithinCutoff
        )
    }

    static func rankedSubnet(_ item: BittensorApi.SubnetRanking) throws -> SubtensorRankedSubnet {
        try SubtensorRankedSubnet(
            netuid: item.netuid,
            taoIn: item.taoIn.map { try BittensorApiDecimal.decimal($0) },
            volatility: item.breakdown.map { breakdown in
                try SubtensorMetricScore(
                    raw: breakdown.volatility.raw.map { try BittensorApiDecimal.decimal($0) },
                    normalized: BittensorApiDecimal.decimal(breakdown.volatility.normalized)
                )
            },
            ageBlocks: item.ageBlocks
        )
    }

    static func makeGeneration(
        _ meta: BittensorApi.RecommendationMetadata,
        isFromExpiredCache: Bool
    ) -> SubtensorRecommendationGeneration {
        SubtensorRecommendationGeneration(
            sourceBlockNumber: meta.generation.sourceBlockNumber,
            carriedOverNetuids: meta.generation.carriedOverNetuids,
            stamp: SubtensorBackendStamp(
                component: meta.components.recommendations,
                isFromExpiredCache: isFromExpiredCache
            )
        )
    }
}

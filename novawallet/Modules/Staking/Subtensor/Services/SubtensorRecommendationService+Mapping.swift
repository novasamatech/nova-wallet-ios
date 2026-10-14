import Foundation
import BigInt

extension SubtensorRecommendationService {
    static let requiredClientChecks: [BittensorApi.ClientCheck] = [.uid, .validatorPermit, .take, .lastUpdate]
    static let maxScoreHundredths = BigUInt(10000)

    static func clientGates(
        _ gates: BittensorApi.ClientGates,
        reader: BittensorApiFieldReader
    ) throws -> SubtensorClientGates {
        guard
            let maxTake = try? BittensorApiDecimal.fraction(gates.maxTake),
            maxTake.numerator > 0,
            maxTake.numerator <= maxTake.denominator else {
            throw reader.violation("meta.clientGates.maxTake")
        }

        return SubtensorClientGates(
            maxTake: maxTake,
            requirePermit: gates.requirePermit,
            requireActiveWithinCutoff: gates.requireActiveWithinCutoff
        )
    }

    static func metric(
        _ metric: BittensorApi.MetricScore,
        _ field: String,
        reader: BittensorApiFieldReader
    ) throws -> SubtensorMetricScore {
        let raw = try reader.optionalDecimal(metric.raw, "\(field).raw")
        let hundredths = try? BittensorApiDecimal.atomic(metric.normalized, scale: 2)

        try reader.require(hundredths.map { $0 <= maxScoreHundredths } ?? false, "\(field).normalized")

        return try SubtensorMetricScore(raw: raw, normalized: reader.decimal(metric.normalized, "\(field).normalized"))
    }

    static func rankedSubnet(
        _ item: BittensorApi.SubnetRanking,
        _ path: String,
        reader: BittensorApiFieldReader
    ) throws -> SubtensorRankedSubnet {
        try SubtensorRankedSubnet(
            netuid: item.netuid,
            status: rankedStatus(item.status),
            taoIn: reader.optionalDecimal(item.taoIn, "\(path).taoIn"),
            volatility: item.breakdown.map {
                try metric($0.volatility, "\(path).breakdown.volatility", reader: reader)
            },
            ageBlocks: item.ageBlocks,
            scoredValidators: Int(clamping: item.validators.scored)
        )
    }

    static func rankedStatus(_ status: BittensorApi.RankingStatus) -> SubtensorRankedSubnet.Status {
        switch status {
        case .scored:
            return .scored
        case .gated:
            return .gated
        case .unavailable:
            return .unavailable
        }
    }

    static func makeGeneration(
        _ meta: BittensorApi.RecommendationMetadata,
        receivedAt: TimeInterval,
        isFromExpiredCache: Bool
    ) -> SubtensorRecommendationGeneration {
        SubtensorRecommendationGeneration(
            sourceBlockNumber: meta.generation.sourceBlockNumber,
            receivedAt: receivedAt,
            carriedOverNetuids: meta.generation.carriedOverNetuids,
            stamp: SubtensorBackendStamp(
                component: meta.components.recommendations,
                isFromExpiredCache: isFromExpiredCache
            )
        )
    }
}

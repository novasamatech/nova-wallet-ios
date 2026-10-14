import Foundation

extension SubtensorRecommendationService {
    struct DecimalReader {
        let route: String
        let requestId: String?

        func violation(_ field: String) -> BittensorApiError {
            .contractViolation(detail: "GET \(route): invalid \(field)", requestId: requestId)
        }

        func decimal(_ value: String, _ field: @autoclosure () -> String) throws -> Decimal {
            do {
                return try BittensorApiDecimal.decimal(value)
            } catch {
                throw violation(field())
            }
        }

        func optionalDecimal(_ value: String?, _ field: @autoclosure () -> String) throws -> Decimal? {
            guard let value else {
                return nil
            }

            return try decimal(value, field())
        }

        func metric(_ metric: BittensorApi.MetricScore, _ field: String) throws -> SubtensorMetricScore {
            try SubtensorMetricScore(
                raw: optionalDecimal(metric.raw, "\(field).raw"),
                normalized: decimal(metric.normalized, "\(field).normalized")
            )
        }

        func clientGates(_ gates: BittensorApi.ClientGates) throws -> SubtensorClientGates {
            do {
                return try SubtensorClientGates(
                    maxTake: BittensorApiDecimal.fraction(gates.maxTake),
                    requirePermit: gates.requirePermit,
                    requireActiveWithinCutoff: gates.requireActiveWithinCutoff
                )
            } catch {
                throw violation("meta.clientGates.maxTake")
            }
        }

        func rankedSubnet(_ item: BittensorApi.SubnetRanking, _ path: String) throws -> SubtensorRankedSubnet {
            try SubtensorRankedSubnet(
                netuid: item.netuid,
                status: SubtensorRecommendationService.rankedStatus(item.status),
                taoIn: optionalDecimal(item.taoIn, "\(path).taoIn"),
                volatility: item.breakdown.map { try metric($0.volatility, "\(path).breakdown.volatility") },
                ageBlocks: item.ageBlocks,
                scoredValidators: Int(clamping: item.validators.scored)
            )
        }
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

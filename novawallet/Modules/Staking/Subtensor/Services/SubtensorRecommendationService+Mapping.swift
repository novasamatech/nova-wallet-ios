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
                normalized: decimal(metric.normalized, "\(field).normalized"),
                weight: decimal(metric.weight, "\(field).weight"),
                isDerived: metric.source == .derived,
                flags: metric.flags
            )
        }

        func optionalMetric(_ metric: BittensorApi.MetricScore?, _ field: String) throws -> SubtensorMetricScore? {
            guard let metric else {
                return nil
            }

            return try self.metric(metric, field)
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

        func breakdown(
            _ breakdown: BittensorApi.RecommendationBreakdown,
            _ path: String
        ) throws -> SubtensorRecommendationBreakdown {
            try SubtensorRecommendationBreakdown(
                volatility: optionalMetric(breakdown.volatility, "\(path).volatility"),
                maxDrawdown: optionalMetric(breakdown.maxDrawdown, "\(path).maxDrawdown"),
                poolDepth: optionalMetric(breakdown.poolDepth, "\(path).poolDepth"),
                age: optionalMetric(breakdown.age, "\(path).age"),
                emissionStability: optionalMetric(breakdown.emissionStability, "\(path).emissionStability"),
                stakeConcentration: optionalMetric(breakdown.stakeConcentration, "\(path).stakeConcentration"),
                permitMargin: optionalMetric(breakdown.permitMargin, "\(path).permitMargin"),
                rootStakeMargin: optionalMetric(breakdown.rootStakeMargin, "\(path).rootStakeMargin"),
                vtrust: metric(breakdown.vtrust, "\(path).vtrust")
            )
        }

        func subnetBreakdown(
            _ breakdown: BittensorApi.SubnetBreakdown,
            _ path: String
        ) throws -> SubtensorSubnetBreakdown {
            try SubtensorSubnetBreakdown(
                volatility: metric(breakdown.volatility, "\(path).volatility"),
                maxDrawdown: metric(breakdown.maxDrawdown, "\(path).maxDrawdown"),
                poolDepth: metric(breakdown.poolDepth, "\(path).poolDepth"),
                age: metric(breakdown.age, "\(path).age"),
                emissionStability: metric(breakdown.emissionStability, "\(path).emissionStability"),
                stakeConcentration: metric(breakdown.stakeConcentration, "\(path).stakeConcentration")
            )
        }

        func pair(
            _ item: BittensorApi.Recommendation,
            hotkey: AccountId,
            path: String,
            verification: SubtensorPairVerification
        ) throws -> SubtensorRecommendedPair {
            try SubtensorRecommendedPair(
                netuid: item.netuid,
                hotkey: hotkey,
                subnetName: item.subnetName,
                symbol: item.symbol,
                validatorName: item.validatorName,
                score: decimal(item.score, "\(path).score"),
                subnetRisk: optionalDecimal(item.subnetRisk, "\(path).subnetRisk"),
                validatorRisk: decimal(item.validatorRisk, "\(path).validatorRisk"),
                breakdown: breakdown(item.breakdown, "\(path).breakdown"),
                effectiveStakeAlpha: decimal(item.effectiveStakeAlpha, "\(path).effectiveStakeAlpha"),
                rootStakeTao: decimal(item.rootStakeTao, "\(path).rootStakeTao"),
                priceTao: optionalDecimal(item.priceTao, "\(path).priceTao"),
                flags: item.flags,
                verification: verification
            )
        }

        func rankedSubnet(_ item: BittensorApi.SubnetRanking, _ path: String) throws -> SubtensorRankedSubnet {
            try SubtensorRankedSubnet(
                netuid: item.netuid,
                subnetName: item.subnetName,
                symbol: item.symbol,
                status: SubtensorRecommendationService.rankedStatus(item.status),
                isEligible: item.eligible,
                reasons: item.reasons,
                riskClass: item.riskClass.map { SubtensorRecommendationService.recommendationClass($0) },
                subnetRisk: optionalDecimal(item.subnetRisk, "\(path).subnetRisk"),
                breakdown: item.breakdown.map { try subnetBreakdown($0, "\(path).breakdown") },
                taoIn: optionalDecimal(item.taoIn, "\(path).taoIn"),
                priceTao: optionalDecimal(item.priceTao, "\(path).priceTao"),
                ageBlocks: item.ageBlocks,
                scoredValidators: Int(clamping: item.validators.scored),
                eligibleValidators: Int(clamping: item.validators.eligible),
                flags: item.flags
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

    static func recommendationClass(_ rankedClass: BittensorApi.RankedClass) -> SubtensorRecommendationClass {
        switch rankedClass {
        case .stable:
            return .stable
        case .balanced:
            return .balanced
        case .higherUpside:
            return .higherUpside
        case .aboveThreshold:
            return .aboveThreshold
        }
    }

    static func policy(_ policy: BittensorApi.Policy) -> SubtensorRecommendationPolicy {
        let classification: SubtensorRecommendationPolicy.Classification

        switch policy.classification {
        case .pair:
            classification = .pair
        case .subnet:
            classification = .subnet
        }

        let insufficientHistory: SubtensorRecommendationPolicy.HistoryPolicy

        switch policy.insufficientHistory {
        case .neutral:
            insufficientHistory = .neutral
        case .exclude:
            insufficientHistory = .exclude
        }

        return SubtensorRecommendationPolicy(
            classification: classification,
            requiresIdentity: policy.requireIdentity,
            requiresPositiveSignal: policy.requirePositiveSignal,
            insufficientHistory: insufficientHistory
        )
    }

    static func makeGeneration(
        _ generation: BittensorApi.Generation,
        component: BittensorApi.AvailableComponent,
        completeness: BittensorApi.Completeness,
        receivedAt: TimeInterval,
        isFromExpiredCache: Bool
    ) -> SubtensorRecommendationGeneration {
        SubtensorRecommendationGeneration(
            id: generation.id,
            sourceBlockNumber: generation.sourceBlockNumber,
            modelVersion: generation.modelVersion,
            ageSeconds: Int64(clamping: generation.ageSeconds),
            receivedAt: receivedAt,
            isServedFromMemory: generation.servedFrom == .memory,
            excludedNetuids: generation.excludedNetuids,
            carriedOverNetuids: generation.carriedOverNetuids,
            inputFlags: generation.inputFlags,
            stamp: SubtensorBackendStamp(component: component, isFromExpiredCache: isFromExpiredCache),
            isPartial: completeness == .partial
        )
    }
}

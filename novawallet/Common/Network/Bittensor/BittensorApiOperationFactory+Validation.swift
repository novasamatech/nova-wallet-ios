import Foundation
import BigInt

enum BittensorApiWireCheck {
    static let clientChecks: [BittensorApi.ClientCheck] = [.uid, .validatorPermit, .take, .lastUpdate]
    static let rootYieldKind = "ROOT_AGGREGATE_APY"
    static let alphaYieldKind = "ALPHA_VALIDATOR_APY"
    static let historyScope = "TAO_APP_PARTIAL"
    static let maxScoreHundredths = BigUInt(10000)
    static let maxScaledAtomic = BigUInt(UInt64.max)
    static let u256Bound = BigUInt(1) << 256

    static func decimal(_ value: String?, _ field: @autoclosure () -> String) throws {
        guard let value else {
            return
        }

        _ = try parsed(field) { try BittensorApiDecimal.decimal(value) }
    }

    static func score(_ value: String?, _ field: @autoclosure () -> String) throws {
        guard let value else {
            return
        }

        let hundredths = try parsed(field) { try BittensorApiDecimal.atomic(value, scale: 2) }

        try require(hundredths <= maxScoreHundredths, field)
    }

    static func scaledAmount(_ value: String, _ field: @autoclosure () -> String) throws {
        let atomic = try parsed(field) { try BittensorApiDecimal.atomic(value, scale: 9) }

        try require(atomic <= maxScaledAtomic, field)
    }

    static func unsignedInteger(_ value: String, _ field: @autoclosure () -> String) throws {
        let atomic = try parsed(field) { try BittensorApiDecimal.atomic(value, scale: 0) }

        try require(atomic < u256Bound, field)
    }

    static func clientGates(_ gates: BittensorApi.ClientGates, _ field: @autoclosure () -> String) throws {
        let maxTake = try parsed(field) { try BittensorApiDecimal.fraction(gates.maxTake) }

        try require(maxTake.numerator > 0 && maxTake.numerator <= maxTake.denominator, field)
    }

    static func metric(_ metric: BittensorApi.MetricScore?, _ field: @autoclosure () -> String) throws {
        guard let metric else {
            return
        }

        try decimal(metric.raw, "\(field()).raw")
        try score(metric.normalized, "\(field()).normalized")
        try decimal(metric.weight, "\(field()).weight")
    }

    static func require(_ condition: Bool, _ field: () -> String) throws {
        guard condition else {
            throw BittensorApiWireViolation(field: field())
        }
    }

    private static func parsed<T>(_ field: () -> String, _ parse: () throws -> T) throws -> T {
        do {
            return try parse()
        } catch {
            throw BittensorApiWireViolation(field: field())
        }
    }
}

extension BittensorApi.SubnetCollection: BittensorApiWireChecked {
    func validateWire() throws {
        for (index, item) in items.enumerated() {
            try BittensorApiWireCheck.decimal(item.reportedRootProportion, "items[\(index)].reportedRootProportion")
            try BittensorApiWireCheck.scaledAmount(item.taoReserve, "items[\(index)].taoReserve")
            try BittensorApiWireCheck.scaledAmount(item.alphaReserve, "items[\(index)].alphaReserve")
            try BittensorApiWireCheck.scaledAmount(item.alphaOutstanding, "items[\(index)].alphaOutstanding")
            try BittensorApiWireCheck.scaledAmount(item.taoPerAlpha, "items[\(index)].taoPerAlpha")
        }
    }
}

extension BittensorApi.ValidatorCollection: BittensorApiWireChecked {
    func validateWire() throws {
        for (index, item) in items.enumerated() {
            let measurements = item.reportedMeasurements

            let fields: [(String, String?)] = [
                ("validatorStake", measurements.validatorStake),
                ("metagraphStake", measurements.metagraphStake),
                ("reportedTaoStake", measurements.reportedTaoStake),
                ("reportedAlphaStake", measurements.reportedAlphaStake),
                ("reportedNominatedStake", measurements.reportedNominatedStake),
                ("reportedValidatorTrust", measurements.reportedValidatorTrust),
                ("reportedTrust", measurements.reportedTrust),
                ("reportedDividend", measurements.reportedDividend),
                ("reportedIncentive", measurements.reportedIncentive),
                ("reportedEmission", measurements.reportedEmission),
                ("reportedTaoDividendsPerHotkey", measurements.reportedTaoDividendsPerHotkey),
                ("reportedAlphaDividendsPerHotkey", measurements.reportedAlphaDividendsPerHotkey)
            ]

            for (name, value) in fields {
                try BittensorApiWireCheck.decimal(value, "items[\(index)].reportedMeasurements.\(name)")
            }
        }
    }
}

extension BittensorApi.RootYieldCollection: BittensorApiWireChecked {
    func validateWire() throws {
        for (index, item) in items.enumerated() {
            try BittensorApiWireCheck.require(item.metricKind == BittensorApiWireCheck.rootYieldKind) {
                "items[\(index)].metricKind"
            }
            try BittensorApiWireCheck.decimal(item.reportedRate, "items[\(index)].reportedRate")
            try BittensorApiWireCheck.decimal(item.reportedRootEmission, "items[\(index)].reportedRootEmission")
        }
    }
}

extension BittensorApi.AlphaYieldCollection: BittensorApiWireChecked {
    func validateWire() throws {
        for (index, item) in items.enumerated() {
            try BittensorApiWireCheck.require(item.metricKind == BittensorApiWireCheck.alphaYieldKind) {
                "items[\(index)].metricKind"
            }

            let fields: [(String, String)] = [
                ("reportedRate", item.reportedRate),
                ("reportedValidatorTrust", item.reportedValidatorTrust),
                ("reportedAlphaDividendsPerHotkey", item.reportedAlphaDividendsPerHotkey),
                ("reportedAlphaStake", item.reportedAlphaStake),
                ("reportedNominatedStake", item.reportedNominatedStake)
            ]

            for (name, value) in fields {
                try BittensorApiWireCheck.decimal(value, "items[\(index)].\(name)")
            }
        }
    }
}

extension BittensorApi.RewardCollection: BittensorApiWireChecked {
    func validateWire() throws {
        try BittensorApiWireCheck.require(historyScope == BittensorApiWireCheck.historyScope) { "historyScope" }

        for (index, item) in items.enumerated() {
            try BittensorApiWireCheck.unsignedInteger(item.reportedAmount, "items[\(index)].reportedAmount")
            try BittensorApiWireCheck.decimal(item.reportedPrice, "items[\(index)].reportedPrice")
        }
    }
}

extension BittensorApi.OperationCollection: BittensorApiWireChecked {
    func validateWire() throws {
        try BittensorApiWireCheck.require(historyScope == BittensorApiWireCheck.historyScope) { "historyScope" }

        for (index, item) in items.enumerated() {
            try BittensorApiWireCheck.decimal(item.reportedAmountIn, "items[\(index)].reportedAmountIn")
            try BittensorApiWireCheck.decimal(item.reportedAmountOut, "items[\(index)].reportedAmountOut")
            try BittensorApiWireCheck.decimal(item.reportedPrice, "items[\(index)].reportedPrice")
        }
    }
}

extension BittensorApi.RecommendationCollection: BittensorApiWireChecked, BittensorApiGenerationalResponse {
    var generationOrder: BittensorApiGenerationOrder {
        BittensorApiGenerationOrder(
            asOf: meta.components.recommendations.asOf,
            sourceBlockNumber: meta.generation.sourceBlockNumber
        )
    }

    var isServedFromMemory: Bool {
        meta.generation.servedFrom == .memory
    }

    func validateWire() throws {
        try BittensorApiWireCheck.clientGates(meta.clientGates, "meta.clientGates.maxTake")

        let groups: [(String, [BittensorApi.Recommendation])] = [
            ("stable", classes.stable),
            ("balanced", classes.balanced),
            ("higherUpside", classes.higherUpside)
        ]

        for (name, recommendations) in groups {
            for (index, recommendation) in recommendations.enumerated() {
                try recommendation.validateWire(at: "classes.\(name)[\(index)]")
            }
        }
    }
}

extension BittensorApi.Recommendation {
    func validateWire(at path: String) throws {
        try BittensorApiWireCheck.require(clientChecks == BittensorApiWireCheck.clientChecks) {
            "\(path).clientChecks"
        }

        try BittensorApiWireCheck.score(score, "\(path).score")
        try BittensorApiWireCheck.score(subnetRisk, "\(path).subnetRisk")
        try BittensorApiWireCheck.score(validatorRisk, "\(path).validatorRisk")
        try BittensorApiWireCheck.decimal(effectiveStakeAlpha, "\(path).effectiveStakeAlpha")
        try BittensorApiWireCheck.decimal(rootStakeTao, "\(path).rootStakeTao")
        try BittensorApiWireCheck.decimal(vtrust, "\(path).vtrust")
        try BittensorApiWireCheck.decimal(priceTao, "\(path).priceTao")

        let metrics: [(String, BittensorApi.MetricScore?)] = [
            ("volatility", breakdown.volatility),
            ("maxDrawdown", breakdown.maxDrawdown),
            ("poolDepth", breakdown.poolDepth),
            ("age", breakdown.age),
            ("emissionStability", breakdown.emissionStability),
            ("stakeConcentration", breakdown.stakeConcentration),
            ("permitMargin", breakdown.permitMargin),
            ("rootStakeMargin", breakdown.rootStakeMargin),
            ("vtrust", breakdown.vtrust)
        ]

        for (name, metric) in metrics {
            try BittensorApiWireCheck.metric(metric, "\(path).breakdown.\(name)")
        }
    }
}

extension BittensorApi.SubnetRankingCollection: BittensorApiWireChecked, BittensorApiGenerationalResponse {
    var generationOrder: BittensorApiGenerationOrder {
        BittensorApiGenerationOrder(
            asOf: meta.components.recommendations.asOf,
            sourceBlockNumber: meta.generation.sourceBlockNumber
        )
    }

    var isServedFromMemory: Bool {
        meta.generation.servedFrom == .memory
    }

    func validateWire() throws {
        try BittensorApiWireCheck.clientGates(meta.clientGates, "meta.clientGates.maxTake")

        for (index, item) in items.enumerated() {
            let path = "items[\(index)]"

            try BittensorApiWireCheck.score(item.subnetRisk, "\(path).subnetRisk")
            try BittensorApiWireCheck.decimal(item.taoIn, "\(path).taoIn")
            try BittensorApiWireCheck.decimal(item.priceTao, "\(path).priceTao")

            guard let breakdown = item.breakdown else {
                continue
            }

            let metrics: [(String, BittensorApi.MetricScore)] = [
                ("volatility", breakdown.volatility),
                ("maxDrawdown", breakdown.maxDrawdown),
                ("poolDepth", breakdown.poolDepth),
                ("age", breakdown.age),
                ("emissionStability", breakdown.emissionStability),
                ("stakeConcentration", breakdown.stakeConcentration)
            ]

            for (name, metric) in metrics {
                try BittensorApiWireCheck.metric(metric, "\(path).breakdown.\(name)")
            }
        }
    }
}

import Foundation
import BigInt

enum BittensorApiWireCheck {
    static let clientChecks: [BittensorApi.ClientCheck] = [.uid, .validatorPermit, .take, .lastUpdate]
    static let alphaYieldKind = "ALPHA_VALIDATOR_APY"
    static let historyScope = "TAO_APP_PARTIAL"
    static let maxScoreHundredths = BigUInt(10000)
    static let maxScaledAtomic = BigUInt(UInt64.max)

    static func decimal(_ value: String?, _ field: @autoclosure () -> String) throws {
        guard let value else {
            return
        }

        _ = try parsed(field) { try BittensorApiDecimal.decimal(value) }
    }

    static func score(_ value: String, _ field: @autoclosure () -> String) throws {
        let hundredths = try parsed(field) { try BittensorApiDecimal.atomic(value, scale: 2) }

        try require(hundredths <= maxScoreHundredths, field)
    }

    static func scaledAmount(_ value: String, _ field: @autoclosure () -> String) throws {
        let atomic = try parsed(field) { try BittensorApiDecimal.atomic(value, scale: 9) }

        try require(atomic <= maxScaledAtomic, field)
    }

    static func clientGates(_ gates: BittensorApi.ClientGates, _ field: @autoclosure () -> String) throws {
        let maxTake = try parsed(field) { try BittensorApiDecimal.fraction(gates.maxTake) }

        try require(maxTake.numerator > 0 && maxTake.numerator <= maxTake.denominator, field)
    }

    static func metric(_ metric: BittensorApi.MetricScore, _ field: @autoclosure () -> String) throws {
        try decimal(metric.raw, "\(field()).raw")
        try score(metric.normalized, "\(field()).normalized")
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
            try BittensorApiWireCheck.decimal(
                item.reportedMeasurements.validatorStake,
                "items[\(index)].reportedMeasurements.validatorStake"
            )
        }
    }
}

extension BittensorApi.AlphaYieldCollection: BittensorApiWireChecked {
    func validateWire() throws {
        for (index, item) in items.enumerated() {
            try BittensorApiWireCheck.require(item.metricKind == BittensorApiWireCheck.alphaYieldKind) {
                "items[\(index)].metricKind"
            }

            try BittensorApiWireCheck.decimal(item.reportedRate, "items[\(index)].reportedRate")
        }
    }
}

extension BittensorApi.RootValidatorCollection: BittensorApiWireChecked {
    func validateWire() throws {
        for (index, item) in items.enumerated() {
            try BittensorApiWireCheck.decimal(item.rootStakeTao, "items[\(index)].rootStakeTao")
            try BittensorApiWireCheck.decimal(item.stakeYield.d30?.apy, "items[\(index)].stakeYield.d30.apy")
        }
    }
}

extension BittensorApi.RootOverview: BittensorApiWireChecked {
    func validateWire() throws {
        try BittensorApiWireCheck.decimal(
            validatorYield?.stakeWeightedApy24h,
            "validatorYield.stakeWeightedApy24h"
        )
    }
}

extension BittensorApi.OperationCollection: BittensorApiWireChecked {
    func validateWire() throws {
        try BittensorApiWireCheck.require(historyScope == BittensorApiWireCheck.historyScope) { "historyScope" }
        try validatePageInfo()

        for (index, item) in items.enumerated() {
            try BittensorApiWireCheck.decimal(item.reportedAmountIn, "items[\(index)].reportedAmountIn")
            try BittensorApiWireCheck.decimal(item.reportedAmountOut, "items[\(index)].reportedAmountOut")
            try BittensorApiWireCheck.decimal(item.reportedPrice, "items[\(index)].reportedPrice")
        }
    }

    private func validatePageInfo() throws {
        let pageRange = BittensorApiOperationFactory.pageRange

        try BittensorApiWireCheck.require(pageInfo.pageSize == BittensorApiOperationFactory.pageSize) {
            "pageInfo.pageSize"
        }

        try BittensorApiWireCheck.require(pageRange.contains(pageInfo.page)) { "pageInfo.page" }
        try BittensorApiWireCheck.require(items.count <= pageInfo.pageSize) { "items" }

        let isNextPageValid = pageInfo.nextPage.map { $0 == pageInfo.page + 1 && pageRange.contains($0) } ?? true

        try BittensorApiWireCheck.require(isNextPageValid) { "pageInfo.nextPage" }
    }
}

extension BittensorApi.RecommendationCollection: BittensorApiWireChecked {
    func validateWire() throws {
        try BittensorApiWireCheck.clientGates(meta.clientGates, "meta.clientGates.maxTake")

        let groups: [(String, [BittensorApi.Recommendation])] = [
            ("stable", classes.stable),
            ("balanced", classes.balanced),
            ("higherUpside", classes.higherUpside)
        ]

        for (name, recommendations) in groups {
            for (index, recommendation) in recommendations.enumerated() {
                try BittensorApiWireCheck.require(recommendation.clientChecks == BittensorApiWireCheck.clientChecks) {
                    "classes.\(name)[\(index)].clientChecks"
                }
            }
        }
    }
}

extension BittensorApi.SubnetRankingCollection: BittensorApiWireChecked {
    func validateWire() throws {
        try BittensorApiWireCheck.clientGates(meta.clientGates, "meta.clientGates.maxTake")

        for (index, item) in items.enumerated() {
            let path = "items[\(index)]"

            try BittensorApiWireCheck.decimal(item.taoIn, "\(path).taoIn")

            if let breakdown = item.breakdown {
                try BittensorApiWireCheck.metric(breakdown.volatility, "\(path).breakdown.volatility")
            }
        }
    }
}

extension BittensorApi.PortfolioHistoryCollection: BittensorApiWireChecked {
    static let maxPoints = 512

    func validateWire() throws {
        try BittensorApiWireCheck.require(historyScope == BittensorApiWireCheck.historyScope) { "historyScope" }
        try BittensorApiWireCheck.require(points.count <= Self.maxPoints) { "points" }

        guard
            let start = BittensorApi.instant(from: window.start),
            let end = BittensorApi.instant(from: window.end),
            start <= end else {
            throw BittensorApiWireViolation(field: "window")
        }

        var previous: Date?

        for (index, point) in points.enumerated() {
            let field = "points[\(index)]"

            guard
                let timestamp = BittensorApi.instant(from: point.timestamp),
                (start ... end).contains(timestamp),
                previous.map({ $0 < timestamp }) ?? true else {
                throw BittensorApiWireViolation(field: "\(field).timestamp")
            }

            try BittensorApiWireCheck.decimal(point.reportedValueTao, "\(field).reportedValueTao")
            try BittensorApiWireCheck.decimal(point.reportedValueUsd, "\(field).reportedValueUsd")

            previous = timestamp
        }
    }
}

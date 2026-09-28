import Foundation

struct SubtensorSubnetFactorsInput {
    let ageBlocks: UInt64?
    let poolTao: Decimal?
    let validatorCount: Int?
    let volatility: SubtensorMetricScore?
    let listedSince: Date?
    let isNotListed: Bool
    let now: Date
}

extension SubtensorSubnetFactorsInput {
    init(rankedSubnet: SubtensorRankedSubnet?, listedSince: Date?, isNotListed: Bool, now: Date) {
        ageBlocks = rankedSubnet?.ageBlocks
        poolTao = rankedSubnet?.taoIn
        validatorCount = rankedSubnet.flatMap { $0.status == .scored ? $0.scoredValidators : nil }
        volatility = rankedSubnet?.breakdown?.volatility
        self.listedSince = listedSince
        self.isNotListed = isNotListed
        self.now = now
    }
}

struct SubtensorSubnetFactor: Equatable {
    enum Kind: CaseIterable, Equatable {
        case age
        case validators
        case pool
        case priceHistory
        case steadiness
    }

    enum Verdict: Equatable {
        case safer
        case riskier
        case unknown
    }

    enum PoolTier: Equatable {
        case deep
        case regular
        case thin
    }

    enum Value: Equatable {
        case duration(TimeInterval)
        case count(Int)
        case pool(Decimal, tier: PoolTier)
        case volatility(Decimal)
        case notListed
        case unknown
    }

    let kind: Kind
    let verdict: Verdict
    let value: Value
}

struct SubtensorSubnetFactorsEvaluation: Equatable {
    let factors: [SubtensorSubnetFactor]

    var saferCount: Int {
        factors.filter { $0.verdict == .safer }.count
    }

    var isSafer: Bool {
        saferCount >= SubtensorSubnetFactorsEvaluator.saferFactorsMinimum
    }

    func factor(_ kind: SubtensorSubnetFactor.Kind) -> SubtensorSubnetFactor {
        factors.first { $0.kind == kind } ?? SubtensorSubnetFactor(kind: kind, verdict: .unknown, value: .unknown)
    }
}

enum SubtensorSubnetFactorsEvaluator {
    static let saferFactorsMinimum = 3
    static let saferAgeMonths: UInt64 = 6
    static let saferValidatorCount = 10
    static let deepPoolTao: Decimal = 25000
    static let thinPoolTao: Decimal = 2000
    static let saferPriceHistoryMonths: UInt64 = 3
    static let calmerVolatilityScore: Decimal = 50

    static func evaluate(_ input: SubtensorSubnetFactorsInput) -> SubtensorSubnetFactorsEvaluation {
        let factors = SubtensorSubnetFactor.Kind.allCases.map { kind in
            switch kind {
            case .age:
                return ageFactor(for: input.ageBlocks)
            case .validators:
                return validatorsFactor(for: input.validatorCount)
            case .pool:
                return poolFactor(for: input.poolTao)
            case .priceHistory:
                return priceHistoryFactor(
                    listedSince: input.listedSince,
                    isNotListed: input.isNotListed,
                    now: input.now
                )
            case .steadiness:
                return steadinessFactor(for: input.volatility)
            }
        }

        return SubtensorSubnetFactorsEvaluation(factors: factors)
    }

    static func poolTier(for poolTao: Decimal) -> SubtensorSubnetFactor.PoolTier {
        if poolTao > deepPoolTao {
            return .deep
        }

        if poolTao < thinPoolTao {
            return .thin
        }

        return .regular
    }
}

private extension SubtensorSubnetFactorsEvaluator {
    static let secondsPerMonth: UInt64 = 30 * 24 * 60 * 60

    static func unknownFactor(_ kind: SubtensorSubnetFactor.Kind) -> SubtensorSubnetFactor {
        SubtensorSubnetFactor(kind: kind, verdict: .unknown, value: .unknown)
    }

    static func verdict(isSafer: Bool) -> SubtensorSubnetFactor.Verdict {
        isSafer ? .safer : .riskier
    }

    static func ageFactor(for ageBlocks: UInt64?) -> SubtensorSubnetFactor {
        guard let ageBlocks else {
            return unknownFactor(.age)
        }

        let blockTimeMillis = SubtensorStakingFlowConstants.blockTimeMillis
        let saferAgeBlocks = saferAgeMonths * secondsPerMonth * 1000 / blockTimeMillis
        let ageSeconds = TimeInterval(ageBlocks) * TimeInterval(blockTimeMillis) / 1000

        return SubtensorSubnetFactor(
            kind: .age,
            verdict: verdict(isSafer: ageBlocks > saferAgeBlocks),
            value: .duration(ageSeconds)
        )
    }

    static func validatorsFactor(for validatorCount: Int?) -> SubtensorSubnetFactor {
        guard let validatorCount else {
            return unknownFactor(.validators)
        }

        return SubtensorSubnetFactor(
            kind: .validators,
            verdict: verdict(isSafer: validatorCount > saferValidatorCount),
            value: .count(validatorCount)
        )
    }

    static func poolFactor(for poolTao: Decimal?) -> SubtensorSubnetFactor {
        guard let poolTao, !poolTao.isNaN, poolTao >= 0 else {
            return unknownFactor(.pool)
        }

        let tier = poolTier(for: poolTao)

        return SubtensorSubnetFactor(
            kind: .pool,
            verdict: verdict(isSafer: tier == .deep),
            value: .pool(poolTao, tier: tier)
        )
    }

    static func priceHistoryFactor(listedSince: Date?, isNotListed: Bool, now: Date) -> SubtensorSubnetFactor {
        if isNotListed {
            return SubtensorSubnetFactor(kind: .priceHistory, verdict: .riskier, value: .notListed)
        }

        guard let listedSince else {
            return unknownFactor(.priceHistory)
        }

        let listedSeconds = max(now.timeIntervalSince(listedSince), 0)
        let saferSeconds = TimeInterval(saferPriceHistoryMonths * secondsPerMonth)

        return SubtensorSubnetFactor(
            kind: .priceHistory,
            verdict: verdict(isSafer: listedSeconds > saferSeconds),
            value: .duration(listedSeconds)
        )
    }

    static func steadinessFactor(for volatility: SubtensorMetricScore?) -> SubtensorSubnetFactor {
        guard let volatility, let raw = volatility.raw else {
            return unknownFactor(.steadiness)
        }

        return SubtensorSubnetFactor(
            kind: .steadiness,
            verdict: verdict(isSafer: volatility.normalized < calmerVolatilityScore),
            value: .volatility(raw)
        )
    }
}

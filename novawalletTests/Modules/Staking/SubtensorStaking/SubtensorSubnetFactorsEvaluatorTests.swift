@testable import novawallet
import XCTest

final class SubtensorSubnetFactorsEvaluatorTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_790_000_000)
    private let secondsPerDay: TimeInterval = 86400

    func testChutesLikeSubnetIsSaferOnAllFiveFactors() throws {
        let chutes = try makeRankedSubnet(
            ageBlocks: 4_536_000,
            taoIn: "210000",
            scoredValidators: 24,
            volatility: makeMetric(raw: "0.029", normalized: "21.54")
        )

        let evaluation = SubtensorSubnetFactorsEvaluator.evaluate(
            SubtensorSubnetFactorsInput(
                rankedSubnet: chutes,
                listedSince: now.addingTimeInterval(-360 * secondsPerDay),
                isNotListed: false,
                now: now
            )
        )

        XCTAssertEqual(
            evaluation.factors,
            [
                SubtensorSubnetFactor(kind: .age, verdict: .safer, value: .duration(630 * secondsPerDay)),
                SubtensorSubnetFactor(kind: .validators, verdict: .safer, value: .count(24)),
                SubtensorSubnetFactor(kind: .pool, verdict: .safer, value: .pool(210_000, tier: .deep)),
                SubtensorSubnetFactor(kind: .priceHistory, verdict: .safer, value: .duration(360 * secondsPerDay)),
                SubtensorSubnetFactor(kind: .steadiness, verdict: .safer, value: .volatility(try decimal("0.029")))
            ]
        )
        XCTAssertEqual(evaluation.saferCount, 5)
        XCTAssertTrue(evaluation.isSafer)
    }

    func testYoungThinGatedSubnetIsRiskierOnAgePoolAndPriceHistory() throws {
        let youngThin = try makeRankedSubnet(
            status: .gated,
            ageBlocks: 144_000,
            taoIn: "1200",
            scoredValidators: 3,
            volatility: nil
        )

        let evaluation = SubtensorSubnetFactorsEvaluator.evaluate(
            SubtensorSubnetFactorsInput(rankedSubnet: youngThin, listedSince: nil, isNotListed: true, now: now)
        )

        XCTAssertEqual(
            evaluation.factors,
            [
                SubtensorSubnetFactor(kind: .age, verdict: .riskier, value: .duration(20 * secondsPerDay)),
                SubtensorSubnetFactor(kind: .validators, verdict: .unknown, value: .unknown),
                SubtensorSubnetFactor(kind: .pool, verdict: .riskier, value: .pool(1200, tier: .thin)),
                SubtensorSubnetFactor(kind: .priceHistory, verdict: .riskier, value: .notListed),
                SubtensorSubnetFactor(kind: .steadiness, verdict: .unknown, value: .unknown)
            ]
        )
        XCTAssertFalse(evaluation.isSafer)
    }

    func testMissingInputsLeaveEveryFactorUnknown() {
        let evaluation = SubtensorSubnetFactorsEvaluator.evaluate(
            SubtensorSubnetFactorsInput(rankedSubnet: nil, listedSince: nil, isNotListed: false, now: now)
        )

        XCTAssertEqual(evaluation.factors.map(\.kind), SubtensorSubnetFactor.Kind.allCases)
        XCTAssertEqual(evaluation.factors.map(\.verdict), Array(repeating: .unknown, count: 5))
        XCTAssertEqual(evaluation.saferCount, 0)
        XCTAssertFalse(evaluation.isSafer)
    }

    func testVolatilityWithoutRawInputIsUnknown() throws {
        let scored = try makeRankedSubnet(
            ageBlocks: 4_536_000,
            taoIn: "210000",
            scoredValidators: 24,
            volatility: makeMetric(raw: nil, normalized: "50")
        )

        let evaluation = SubtensorSubnetFactorsEvaluator.evaluate(
            SubtensorSubnetFactorsInput(rankedSubnet: scored, listedSince: nil, isNotListed: false, now: now)
        )

        XCTAssertEqual(
            evaluation.factor(.steadiness),
            SubtensorSubnetFactor(kind: .steadiness, verdict: .unknown, value: .unknown)
        )
    }

    func testFactorsExactlyAtTheirThresholdsAreRiskier() throws {
        let atThresholds = try makeRankedSubnet(
            ageBlocks: 1_296_000,
            taoIn: "25000",
            scoredValidators: 10,
            volatility: makeMetric(raw: "0.0475", normalized: "50")
        )

        let evaluation = SubtensorSubnetFactorsEvaluator.evaluate(
            SubtensorSubnetFactorsInput(
                rankedSubnet: atThresholds,
                listedSince: now.addingTimeInterval(-90 * secondsPerDay),
                isNotListed: false,
                now: now
            )
        )

        XCTAssertEqual(evaluation.factors.map(\.verdict), Array(repeating: .riskier, count: 5))
        XCTAssertEqual(evaluation.factor(.pool).value, .pool(25000, tier: .regular))
        XCTAssertEqual(SubtensorSubnetFactorsEvaluator.poolTier(for: 2000), .regular)
    }

    func testFactorsJustPastTheirThresholdsAreSafer() throws {
        let pastThresholds = try makeRankedSubnet(
            ageBlocks: 1_296_001,
            taoIn: "25000.000000001",
            scoredValidators: 11,
            volatility: makeMetric(raw: "0.0474935", normalized: "49.99")
        )

        let evaluation = SubtensorSubnetFactorsEvaluator.evaluate(
            SubtensorSubnetFactorsInput(
                rankedSubnet: pastThresholds,
                listedSince: now.addingTimeInterval(-90 * secondsPerDay - 1),
                isNotListed: false,
                now: now
            )
        )

        XCTAssertEqual(evaluation.factors.map(\.verdict), Array(repeating: .safer, count: 5))
        XCTAssertEqual(SubtensorSubnetFactorsEvaluator.poolTier(for: try decimal("1999.999999999")), .thin)
    }

    private func makeRankedSubnet(
        status: SubtensorRankedSubnet.Status = .scored,
        ageBlocks: UInt64,
        taoIn: String,
        scoredValidators: Int,
        volatility: SubtensorMetricScore?
    ) throws -> SubtensorRankedSubnet {
        let neutral = try makeMetric(raw: nil, normalized: "50")

        return try SubtensorRankedSubnet(
            netuid: 64,
            subnetName: "Chutes",
            symbol: "ش",
            status: status,
            isEligible: status == .scored,
            reasons: [],
            riskClass: nil,
            subnetRisk: nil,
            breakdown: volatility.map { score in
                SubtensorSubnetBreakdown(
                    volatility: score,
                    maxDrawdown: neutral,
                    poolDepth: neutral,
                    age: neutral,
                    emissionStability: neutral,
                    stakeConcentration: neutral
                )
            },
            taoIn: decimal(taoIn),
            priceTao: nil,
            ageBlocks: ageBlocks,
            scoredValidators: scoredValidators,
            eligibleValidators: scoredValidators,
            flags: []
        )
    }

    private func makeMetric(raw: String?, normalized: String) throws -> SubtensorMetricScore {
        try SubtensorMetricScore(
            raw: raw.map { try decimal($0) },
            normalized: decimal(normalized),
            weight: decimal("0.18"),
            isDerived: true,
            flags: []
        )
    }

    private func decimal(_ value: String) throws -> Decimal {
        try XCTUnwrap(Decimal(string: value, locale: Locale(identifier: "en_US_POSIX")))
    }
}

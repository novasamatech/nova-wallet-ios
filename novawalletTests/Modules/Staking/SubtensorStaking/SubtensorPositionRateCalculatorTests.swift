import BigInt
@testable import novawallet
import XCTest

final class SubtensorPositionRateCalculatorTests: XCTestCase {
    private let positionAlpha = BigUInt(10_000_000_000_000)
    private let chutesTempo: UInt16 = 360

    private func makePosition(
        netuid: UInt16 = 64,
        emission: Balance,
        stake: Balance? = nil,
        totalHotkeyAlpha: Balance?
    ) -> SubtensorStakingPosition {
        SubtensorStakingPosition(
            hotkey: Data(repeating: 0x33, count: 32),
            netuid: netuid,
            stakeAlpha: stake ?? positionAlpha,
            hotkeyEmissionPerTempo: emission,
            totalHotkeyAlpha: totalHotkeyAlpha,
            isRegistered: true
        )
    }

    func testShareScaledRateForALargeDividendPool() {
        let rate = SubtensorPositionRateCalculator.alphaPerDayRao(
            hotkeyEmissionPerTempo: 26_188_601_273,
            positionAlpha: positionAlpha,
            totalHotkeyAlpha: 573_318_341_062_634,
            tempo: chutesTempo
        )

        XCTAssertEqual(rate, BigUInt(9_135_797_478))
    }

    func testShareScaledRateForAMidSizedDividendPool() {
        let rate = SubtensorPositionRateCalculator.alphaPerDayRao(
            hotkeyEmissionPerTempo: 12_308_252_437,
            positionAlpha: positionAlpha,
            totalHotkeyAlpha: 295_775_684_099_303,
            tempo: chutesTempo
        )

        XCTAssertEqual(rate, BigUInt(8_322_693_918))
    }

    func testShareScaledRateForASmallDividendPool() {
        let rate = SubtensorPositionRateCalculator.alphaPerDayRao(
            hotkeyEmissionPerTempo: 97022,
            positionAlpha: 259_140_774,
            totalHotkeyAlpha: 2_591_407_748,
            tempo: chutesTempo
        )

        XCTAssertEqual(rate, BigUInt(194_043))
    }

    func testRateDependsOnTheShareRatioRatherThanItsAbsoluteSize() {
        let base = SubtensorPositionRateCalculator.alphaPerDayRao(
            hotkeyEmissionPerTempo: 26_188_601_273,
            positionAlpha: positionAlpha,
            totalHotkeyAlpha: 573_318_341_062_634,
            tempo: chutesTempo
        )

        let scaled = SubtensorPositionRateCalculator.alphaPerDayRao(
            hotkeyEmissionPerTempo: 26_188_601_273,
            positionAlpha: positionAlpha * 3,
            totalHotkeyAlpha: 573_318_341_062_634 * 3,
            tempo: chutesTempo
        )

        XCTAssertEqual(scaled, base)
    }

    func testRateScalesLinearlyWithPositionShare() throws {
        let full = SubtensorPositionRateCalculator.alphaPerDayRao(
            hotkeyEmissionPerTempo: 26_188_601_273,
            positionAlpha: positionAlpha,
            totalHotkeyAlpha: 573_318_341_062_634,
            tempo: chutesTempo
        )

        let half = SubtensorPositionRateCalculator.alphaPerDayRao(
            hotkeyEmissionPerTempo: 26_188_601_273,
            positionAlpha: positionAlpha / 2,
            totalHotkeyAlpha: 573_318_341_062_634,
            tempo: chutesTempo
        )

        XCTAssertEqual(half, BigUInt(4_567_898_739))
        XCTAssertEqual(full, try XCTUnwrap(half) * 2)
    }

    func testLongerTempoLowersTheDailyRateProportionally() throws {
        let standard = SubtensorPositionRateCalculator.alphaPerDayRao(
            hotkeyEmissionPerTempo: 26_188_601_273,
            positionAlpha: positionAlpha,
            totalHotkeyAlpha: 573_318_341_062_634,
            tempo: 360
        )

        let doubled = SubtensorPositionRateCalculator.alphaPerDayRao(
            hotkeyEmissionPerTempo: 26_188_601_273,
            positionAlpha: positionAlpha,
            totalHotkeyAlpha: 573_318_341_062_634,
            tempo: 720
        )

        XCTAssertEqual(doubled, BigUInt(4_567_898_739))
        XCTAssertEqual(standard, try XCTUnwrap(doubled) * 2)
    }

    func testRateIsNilWithoutHotkeyAlphaDenominator() {
        let rate = SubtensorPositionRateCalculator.alphaPerDayRao(
            hotkeyEmissionPerTempo: 26_188_601_273,
            positionAlpha: positionAlpha,
            totalHotkeyAlpha: 0,
            tempo: chutesTempo
        )

        XCTAssertNil(rate)
    }

    func testRateIsNilWithoutTempo() {
        let rate = SubtensorPositionRateCalculator.alphaPerDayRao(
            hotkeyEmissionPerTempo: 26_188_601_273,
            positionAlpha: positionAlpha,
            totalHotkeyAlpha: 573_318_341_062_634,
            tempo: 0
        )

        XCTAssertNil(rate)
    }

    func testRootPositionsHaveNoDailyAlphaRate() {
        XCTAssertFalse(SubtensorPositionRateCalculator.supportsAlphaPerDay(netuid: 0))

        let rate = SubtensorPositionRateCalculator.alphaPerDayRao(
            for: makePosition(netuid: 0, emission: 0, totalHotkeyAlpha: 5_575_547_743_380_273),
            tempo: 100
        )

        XCTAssertNil(rate)
    }

    func testPositionRateIsNilUntilHotkeyAlphaArrives() {
        let rate = SubtensorPositionRateCalculator.alphaPerDayRao(
            for: makePosition(emission: 26_188_601_273, totalHotkeyAlpha: nil),
            tempo: chutesTempo
        )

        XCTAssertNil(rate)
    }

    func testPositionRateMatchesTheStandaloneComputation() {
        let rate = SubtensorPositionRateCalculator.alphaPerDayRao(
            for: makePosition(
                emission: 26_188_601_273,
                totalHotkeyAlpha: 573_318_341_062_634
            ),
            tempo: chutesTempo
        )

        XCTAssertEqual(rate, BigUInt(9_135_797_478))
    }
}

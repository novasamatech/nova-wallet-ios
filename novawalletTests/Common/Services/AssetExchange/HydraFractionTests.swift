import XCTest
@testable import novawallet
import BigInt

final class HydraFractionTests: XCTestCase {
    private let complement = HydraEmaOracle.Smoothing.tenMinutesComplement

    func testFractionOne() {
        XCTAssertEqual(HydraFraction.one, BigUInt("170141183460469231731687303715884105728"))
    }

    func testTenMinutesSmoothingMatchesRuntimeBits() {
        XCTAssertEqual(
            HydraEmaOracle.Smoothing.tenMinutes,
            BigUInt("3369132345751865974884897103284833777")
        )
    }

    func testTenMinutesSmoothingIsRoundedNotTruncated() {
        let rounded = (2 * HydraFraction.one + 101 / 2) / 101

        XCTAssertEqual(HydraEmaOracle.Smoothing.tenMinutes, rounded)
        XCTAssertNotEqual(HydraEmaOracle.Smoothing.tenMinutes, 2 * HydraFraction.one / 101)
    }

    func testSmoothingComplement() {
        XCTAssertEqual(complement, BigUInt("166772051114717365756802406612599271951"))
    }

    func testMulTruncates() {
        XCTAssertEqual(HydraFraction.mul(HydraFraction.one, HydraFraction.one), HydraFraction.one)
        XCTAssertEqual(
            HydraFraction.mul(HydraFraction.one - 1, HydraFraction.one - 1),
            HydraFraction.one - 2
        )
    }

    func testComplementPowIdentityAndOperand() {
        XCTAssertEqual(HydraEmaOracle.Smoothing.complementPow(staleBlocks: 0), HydraFraction.one)
        XCTAssertEqual(HydraEmaOracle.Smoothing.complementPow(staleBlocks: 1), complement)
    }

    func testComplementPowUsesBinomialSeriesForSmallExponents() {
        let expected: [UInt32: BigUInt] = [
            2: "163469634260960586236865725293537900228",
            3: "160232611800347505321284225782774773491",
            4: "157059688794400029968387508440541609659",
            5: "153949595946986167988815478570431874815"
        ]

        for (staleBlocks, value) in expected {
            XCTAssertEqual(
                HydraEmaOracle.Smoothing.complementPow(staleBlocks: staleBlocks),
                value,
                "mismatch at k = \(staleBlocks)"
            )
        }
    }

    func testBinomialSeriesAndBinaryExponentiationDisagree() {
        XCTAssertEqual(
            HydraFraction.saturatingPow(complement, exponent: 3),
            BigUInt("160232611800347505321284225782774773490")
        )
        XCTAssertEqual(
            HydraFraction.powiNearOne(complement, exponent: 3),
            BigUInt("160232611800347505321284225782774773491")
        )
    }

    func testComplementPowUsesBinaryExponentiationFromSixOnwards() {
        XCTAssertNotNil(HydraFraction.powiNearOne(complement, exponent: 6))

        XCTAssertEqual(
            HydraEmaOracle.Smoothing.complementPow(staleBlocks: 6),
            HydraFraction.saturatingPow(complement, exponent: 6)
        )
        XCTAssertEqual(
            HydraEmaOracle.Smoothing.complementPow(staleBlocks: 6),
            BigUInt("150901089096550798325670617608641144616")
        )
    }

    func testComplementPowLargerExponents() {
        XCTAssertEqual(
            HydraEmaOracle.Smoothing.complementPow(staleBlocks: 10),
            BigUInt("139298890546079292577350221674714116311")
        )
        XCTAssertEqual(
            HydraEmaOracle.Smoothing.complementPow(staleBlocks: 100),
            BigUInt("23024570139214623216308046311784826897")
        )
    }

    func testComplementPowSaturatesAtExactly4402() {
        XCTAssertEqual(HydraEmaOracle.Smoothing.complementPow(staleBlocks: 4399), 1)
        XCTAssertEqual(HydraEmaOracle.Smoothing.complementPow(staleBlocks: 4400), 1)
        XCTAssertEqual(HydraEmaOracle.Smoothing.complementPow(staleBlocks: 4401), 1)
        XCTAssertEqual(HydraEmaOracle.Smoothing.complementPow(staleBlocks: 4402), 0)
        XCTAssertEqual(HydraEmaOracle.Smoothing.complementPow(staleBlocks: 10000), 0)
    }
}

import XCTest
@testable import novawallet
import BigInt

class VotingCurveTests: XCTestCase {
    func testReciprocalCurve() {
        let params = Referenda.ReciprocalCurve(
            factor: 10 * 1_000_000_000,
            xOffset: 1 * 1_000_000_000,
            yOffset: -1 * 1_000_000_000
        )

        let delayStubs: [(Decimal, Decimal)] = [
            (x: .zero, y: 9.0),
            (x: 0.25, y: 7.0),
            (x: 1.0, y: 4.0)
        ]

        let thresholdStubs: [(Decimal, Decimal)] = [
            (x: .zero, y: 1.0),
            (x: 5.25, y: 0.6),
            (x: 7.0, y: 0.25),
            (x: 9.0, y: .zero)
        ]

        let curve = Referenda.Curve.reciprocal(params)

        testDelay(for: curve, with: delayStubs)
        testThreshold(for: curve, with: thresholdStubs)
    }

    func testLinearDecreasingCurve() {
        let params = Referenda.LinearDecreasingCurve(
            length: BigUInt(0.5 * 1_000_000_000),
            floor: BigUInt(0.1 * 1_000_000_000),
            ceil: BigUInt(0.9 * 1_000_000_000)
        )

        let delayStubs: [(Decimal?, Decimal)] = [
            (x: .zero, y: 1.0),
            (x: .zero, y: 0.9),
            (x: 0.25, y: 0.5),
            (x: 0.5, y: 0.1),
            (x: nil, y: 0.09),
            (x: nil, y: .zero)
        ]

        let thresholdStubs: [(Decimal, Decimal)] = [
            (x: .zero, y: 0.9),
            (x: 0.25, y: 0.5),
            (x: 0.5, y: 0.1),
            (x: 1.0, y: 0.1)
        ]

        let curve = Referenda.Curve.linearDecreasing(params)

        testDelay(for: curve, with: delayStubs)
        testThreshold(for: curve, with: thresholdStubs)
    }

    func testSteppedDecreasingCurve() {
        let params = Referenda.SteppedDecreasingCurve(
            begin: BigUInt(0.8 * 1_000_000_000),
            end: BigUInt(0.3 * 1_000_000_000),
            step: BigUInt(0.1 * 1_000_000_000),
            period: BigUInt(0.15 * 1_000_000_000)
        )

        let delayStubs: [(Decimal?, Decimal)] = [
            (x: .zero, y: 0.8),
            (x: 0.15, y: 0.7),
            (x: 0.3, y: 0.6),
            (x: 0.75, y: 0.3),
            (x: nil, y: 0.1)
        ]

        let thresholdStubs: [(Decimal, Decimal)] = [
            (x: .zero, y: 0.8),
            (x: Decimal(0.15).lessEpsilon(), y: 0.8),
            (x: 0.15, y: 0.7),
            (x: Decimal(0.3).lessEpsilon(), y: 0.7),
            (x: 0.3, y: 0.6),
            (x: 1.0, y: 0.3)
        ]

        let curve = Referenda.Curve.steppedDecreasing(params)

        testDelay(for: curve, with: delayStubs)
        testThreshold(for: curve, with: thresholdStubs)
    }

    private func testDelay(
        for curve: Referenda.Curve,
        with stubs: [(x: Decimal?, y: Decimal)]
    ) {
        let function: ReferendumDecidingFunctionProtocol = Gov2LocalDecidingFunction(
            curve: curve,
            startBlock: 0,
            period: 0
        )

        stubs.forEach { expectedX, y in
            let resultX = function.delay(for: y)
            XCTAssertTrue(
                resultX == expectedX,
                "Expected \(String(describing: expectedX)) for input \(y) but got: \(String(describing: resultX))"
            )
        }
    }

    private func testThreshold(
        for curve: Referenda.Curve,
        with stubs: [(x: Decimal, y: Decimal)]
    ) {
        let function: ReferendumDecidingFunctionProtocol = Gov2LocalDecidingFunction(
            curve: curve,
            startBlock: 0,
            period: 0
        )

        stubs.forEach { x, expectedY in
            let resultY = function.calculateThreshold(for: x)
            XCTAssertTrue(resultY == expectedY, "Expected \(expectedY) for input \(x) but got: \(String(describing: resultY))")
        }
    }
}

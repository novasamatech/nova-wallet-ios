@testable import novawallet
import XCTest

final class SubtensorPortfolioValueSeriesCalculatorTests: XCTestCase {
    func testAllTimeHistoryKeepsEveryRegisteredPointAndItsChange() {
        let points = [1_700_000_000, 1_760_000_000, 1_790_000_000].enumerated().map { index, time in
            SubtensorPricePoint(
                date: Date(timeIntervalSince1970: TimeInterval(time)),
                taoPerAlpha: Decimal(index + 1),
                fiatPerAlpha: Decimal(300 * (index + 1))
            )
        }

        let history = SubtensorPriceHistoryOperationFactory.makeHistory(
            subnet: SubtensorSubnetRef(netuid: 3, registeredAt: 0),
            period: .all,
            points: points,
            registrationDate: Date(timeIntervalSince1970: 1_750_000_000)
        )

        XCTAssertEqual(history.points, Array(points.dropFirst()))
        XCTAssertEqual(history.changeInTao, Decimal(string: "0.5"))
    }
}

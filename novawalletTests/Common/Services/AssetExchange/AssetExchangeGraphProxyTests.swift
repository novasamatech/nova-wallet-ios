import XCTest
@testable import novawallet
import Operation_iOS
import BigInt

final class AssetExchangeGraphProxyTests: XCTestCase {
    func testFeeConversionQuoteIsNotGrossedUp() throws {
        let graph = CommissionTestFixtures.makeGraph(paths: [CommissionTestFixtures.createPath([.hydraSwap])])

        let proxy = AssetExchangeGraphProxy(
            pathCostEstimator: MockAssetsExchangePathCostEstimator(),
            operationQueue: OperationQueue(),
            logger: Logger.shared
        )

        proxy.install(graph: graph)

        let quote: AssetConversion.Quote = try withExtendedLifetime(graph) {
            let wrapper = proxy.quote(
                for: AssetConversion.QuoteArgs(
                    assetIn: CommissionTestFixtures.asset(0),
                    assetOut: CommissionTestFixtures.asset(1),
                    amount: 1_000_000_000,
                    direction: .buy
                )
            )

            OperationQueue().addOperations(wrapper.allOperations, waitUntilFinished: true)

            return try wrapper.targetOperation.extractNoCancellableResultData()
        }

        XCTAssertEqual(quote.amountIn, 1_000_000_000)
    }
}

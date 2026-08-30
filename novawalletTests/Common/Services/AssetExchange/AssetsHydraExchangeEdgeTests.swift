import XCTest
@testable import novawallet
import Operation_iOS
import Cuckoo
import BigInt

final class AssetsHydraExchangeEdgeTests: XCTestCase {
    func testTradeLimitNamesTheAssetTheGivenAmountIsDenominatedIn() throws {
        let edge = makeEdge()

        XCTAssertEqual(
            try limitedAsset(reportedBy: edge, direction: .sell),
            CommissionTestFixtures.chainAsset(0)
        )

        XCTAssertEqual(
            try limitedAsset(reportedBy: edge, direction: .buy),
            CommissionTestFixtures.chainAsset(1)
        )
    }
}

private extension AssetsHydraExchangeEdgeTests {
    func makeEdge() -> AssetsHydraExchangeEdge {
        let host = MockHydraExchangeHostProtocol()

        stub(host) { stub in
            stub.chain.get.thenReturn(CommissionTestFixtures.chain)
        }

        return AssetsHydraExchangeEdge(
            origin: CommissionTestFixtures.asset(0),
            destination: CommissionTestFixtures.asset(1),
            remoteSwapPair: HydraDx.RemoteSwapPair(assetIn: 0, assetOut: 1),
            host: host
        )
    }

    func limitedAsset(
        reportedBy edge: AssetsHydraExchangeEdge,
        direction: AssetConversion.Direction,
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws -> ChainAsset {
        let rejection = CompoundOperationWrapper<Balance>.createWithError(
            HydraExchangeTradeLimitError.exceedsPoolTradeLimit(
                HydraExchangePoolTradeCap(maxGivenAmount: 500_000_000, minTradingLimit: 1000)
            )
        )

        let wrapper = edge.namingLimitedAsset(rejection, direction: direction)

        OperationQueue().addOperations(wrapper.allOperations, waitUntilFinished: true)

        var named: ChainAsset?

        XCTAssertThrowsError(
            try wrapper.targetOperation.extractNoCancellableResultData(),
            file: file,
            line: line
        ) { error in
            guard case let HydraExchangeTradeLimitError.exceedsPoolTradeLimit(cap) = error else {
                return XCTFail("unexpected error \(error)", file: file, line: line)
            }

            named = cap?.limitedAsset
        }

        return try XCTUnwrap(named, file: file, line: line)
    }
}

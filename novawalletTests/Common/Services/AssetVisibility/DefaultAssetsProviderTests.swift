import XCTest
@testable import novawallet
import Cuckoo
import Operation_iOS

final class DefaultAssetsProviderTests: XCTestCase {
    private let url = URL(string: "https://github.com")!

    func testOrderKeptFailureEmptySuccessMemoised() throws {
        // given

        let dataOperationFactory = MockDataOperationFactoryProtocol()

        let provider = DefaultAssetsProvider(
            url: url,
            dataOperationFactory: dataOperationFactory,
            logger: Logger.shared
        )

        let ordered = [
            ChainAssetId(chainId: KnowChainId.polkadot, assetId: 7),
            ChainAssetId(chainId: KnowChainId.ethereum, assetId: 0)
        ]

        let config = """
        {
          "defaultAssets": [
            { "chainId": "\(KnowChainId.polkadot)", "assetId": 7 },
            { "chainId": "\(KnowChainId.ethereum)", "assetId": 0 }
          ]
        }
        """

        stub(dataOperationFactory) { stub in
            stub.fetchData(from: any()).thenReturn(
                BaseOperation.createWithError(BaseOperationError.unexpectedDependentResult),
                BaseOperation.createWithResult(Data(#"{"assets":[]}"#.utf8)),
                BaseOperation.createWithResult(Data(config.utf8))
            )
        }

        // when

        let afterTransportFailure = try resolveList(from: provider)
        let afterMissingKey = try resolveList(from: provider)
        let fetched = try resolveList(from: provider)
        let memoised = try resolveList(from: provider)

        // then

        XCTAssertEqual(DefaultAssetsList.empty, afterTransportFailure)
        XCTAssertEqual(DefaultAssetsList.empty, afterMissingKey)

        XCTAssertEqual(ordered, fetched.ids)
        XCTAssertEqual(0, fetched.rank(of: ordered[0]))
        XCTAssertEqual(1, fetched.rank(of: ordered[1]))

        XCTAssertEqual(fetched, memoised)

        verify(dataOperationFactory, times(3)).fetchData(from: any())
    }
}

private extension DefaultAssetsProviderTests {
    func resolveList(from provider: DefaultAssetsProvider) throws -> DefaultAssetsList {
        let wrapper = provider.createDefaultAssetsWrapper()

        OperationQueue().addOperations(wrapper.allOperations, waitUntilFinished: true)

        return try wrapper.targetOperation.extractNoCancellableResultData()
    }
}

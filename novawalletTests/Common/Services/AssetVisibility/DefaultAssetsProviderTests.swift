import Cuckoo
@testable import novawallet
import Operation_iOS
import XCTest

final class DefaultAssetsProviderTests: XCTestCase {
    private let url = URL(string: "https://example.com/default-assets.json")!

    func testUnsupportedVersionFallsBackToAllVisible() throws {
        // given

        let chain = ChainModelGenerator.generateChain(generatingAssets: 1, addressPrefix: 0)
        let data = try makeData(version: 2, ids: [XCTUnwrap(chain.utilityChainAssetId())])
        let provider = makeProvider(data: data, chains: [chain])

        // when

        let list = try fetchList(from: provider)

        // then

        XCTAssertTrue(list.isEmpty)
    }

    func testSupportedVersionKeepsOnlyLocallyResolvedAssets() throws {
        // given

        let chain = ChainModelGenerator.generateChain(generatingAssets: 1, addressPrefix: 0)
        let resolvedId = try XCTUnwrap(chain.utilityChainAssetId())
        let unresolvedId = ChainAssetId(chainId: "unknown-chain", assetId: 42)
        let data = makeData(version: 1, ids: [resolvedId, unresolvedId])
        let provider = makeProvider(data: data, chains: [chain])

        // when

        let list = try fetchList(from: provider)

        // then

        XCTAssertEqual(list.ids, [resolvedId])
    }

    func testConfigurationWithNoLocallyResolvedAssetsFallsBackToAllVisible() throws {
        // given

        let data = makeData(
            version: 1,
            ids: [ChainAssetId(chainId: "unknown-chain", assetId: 42)]
        )
        let provider = makeProvider(data: data, chains: [])

        // when

        let list = try fetchList(from: provider)

        // then

        XCTAssertTrue(list.isEmpty)
    }

    func testVersionlessConfigurationRemainsCompatibleAsVersionOne() throws {
        // given

        let chain = ChainModelGenerator.generateChain(generatingAssets: 1, addressPrefix: 0)
        let resolvedId = try XCTUnwrap(chain.utilityChainAssetId())
        let data = makeData(version: nil, ids: [resolvedId])
        let provider = makeProvider(data: data, chains: [chain])

        // when

        let list = try fetchList(from: provider)

        // then

        XCTAssertEqual(list.ids, [resolvedId])
    }
}

private extension DefaultAssetsProviderTests {
    func makeProvider(data: Data, chains: Set<ChainModel>) -> DefaultAssetsProvider {
        let dataOperationFactory = MockDataOperationFactoryProtocol()
        let chainRegistry = MockChainRegistryProtocol().applyDefault(for: chains)

        stub(dataOperationFactory) { stub in
            stub.fetchData(from: url).thenReturn(BaseOperation.createWithResult(data))
        }

        return DefaultAssetsProvider(
            url: url,
            dataOperationFactory: dataOperationFactory,
            chainRegistry: chainRegistry,
            logger: Logger.shared
        )
    }

    func fetchList(from provider: DefaultAssetsProvider) throws -> DefaultAssetsList {
        let wrapper = provider.createDefaultAssetsWrapper()
        OperationQueue().addOperations(wrapper.allOperations, waitUntilFinished: true)
        return try wrapper.targetOperation.extractNoCancellableResultData()
    }

    func makeData(version: UInt?, ids: [ChainAssetId]) -> Data {
        var object: [String: Any] = [
            "defaultAssets": ids.map {
                ["chainId": $0.chainId, "assetId": $0.assetId]
            }
        ]

        if let version {
            object["version"] = version
        }

        return try! JSONSerialization.data(withJSONObject: object)
    }
}

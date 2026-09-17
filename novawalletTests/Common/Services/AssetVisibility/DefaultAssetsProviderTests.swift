import Cuckoo
import Keystore_iOS
@testable import novawallet
import Operation_iOS
import XCTest

final class DefaultAssetsProviderTests: XCTestCase {
    private let url = URL(string: "https://example.com/default-assets.json")!

    func testPersistedConfigurationIsAvailableBeforeRemoteFetch() throws {
        let chain = ChainModelGenerator.generateChain(generatingAssets: 1, addressPrefix: 0)
        let id = try XCTUnwrap(chain.utilityChainAssetId())
        let settings = InMemorySettingsManager()
        let firstProvider = makeProvider(data: makeData(version: 1, ids: [id]), chains: [chain], settings: settings)
        _ = try fetchList(from: firstProvider)

        let nextProvider = makeProvider(data: Data(), chains: [chain], settings: settings)

        XCTAssertEqual(nextProvider.cachedDefaultAssets?.ids, [id])
        XCTAssertEqual(try fetchList(from: nextProvider).ids, [id])
    }

    func testRefreshReplacesAndPersistsDifferingConfiguration() throws {
        let chain = ChainModelGenerator.generateChain(generatingAssets: 2, addressPrefix: 0)
        let ids = chain.assets.sorted { $0.assetId < $1.assetId }.map {
            ChainAssetId(chainId: chain.chainId, assetId: $0.assetId)
        }
        let settings = InMemorySettingsManager()
        let initialProvider = makeProvider(data: makeData(version: 1, ids: [ids[0]]), chains: [chain], settings: settings)
        _ = try fetchList(from: initialProvider)
        let provider = makeProvider(data: makeData(version: 1, ids: [ids[1]]), chains: [chain], settings: settings)

        XCTAssertEqual(provider.cachedDefaultAssets?.ids, [ids[0]])
        XCTAssertEqual(try execute(provider.createRefreshDefaultAssetsWrapper()).ids, [ids[1]])

        let nextProvider = makeProvider(data: Data(), chains: [chain], settings: settings)
        XCTAssertEqual(nextProvider.cachedDefaultAssets?.ids, [ids[1]])
    }

    func testUnusableRefreshPreservesLastKnownGoodConfiguration() throws {
        let chain = ChainModelGenerator.generateChain(generatingAssets: 1, addressPrefix: 0)
        let id = try XCTUnwrap(chain.utilityChainAssetId())
        let invalidConfigurations = [
            Data(),
            makeData(version: 2, ids: [id]),
            makeData(version: 1, ids: [ChainAssetId(chainId: "unknown", assetId: 0)])
        ]

        for invalidData in invalidConfigurations {
            let settings = InMemorySettingsManager()
            let initialProvider = makeProvider(data: makeData(version: 1, ids: [id]), chains: [chain], settings: settings)
            _ = try fetchList(from: initialProvider)
            let provider = makeProvider(data: invalidData, chains: [chain], settings: settings)

            XCTAssertEqual(try execute(provider.createRefreshDefaultAssetsWrapper()).ids, [id])

            let nextProvider = makeProvider(data: Data(), chains: [chain], settings: settings)
            XCTAssertEqual(nextProvider.cachedDefaultAssets?.ids, [id])
        }
    }

    func testFailedRemoteWithoutCacheFallsBackToAllVisible() throws {
        let factory = MockDataOperationFactoryProtocol()
        stub(factory) {
            $0.fetchData(from: url).thenReturn(BaseOperation.createWithError(CommonError.dataCorruption))
        }
        let provider = DefaultAssetsProvider(
            url: url,
            dataOperationFactory: factory,
            chainRegistry: MockChainRegistryProtocol().applyDefault(for: []),
            settingsManager: InMemorySettingsManager(),
            logger: Logger.shared
        )

        XCTAssertTrue(try fetchList(from: provider).isEmpty)
        XCTAssertNil(provider.cachedDefaultAssets)
    }

    func testPersistedConfigurationIsResolvedAgainstCurrentRegistry() throws {
        let chain = ChainModelGenerator.generateChain(generatingAssets: 1, addressPrefix: 0)
        let id = try XCTUnwrap(chain.utilityChainAssetId())
        let settings = InMemorySettingsManager()
        let firstProvider = makeProvider(data: makeData(version: 1, ids: [id]), chains: [chain], settings: settings)
        _ = try fetchList(from: firstProvider)
        let nextProvider = makeProvider(data: Data(), chains: [], settings: settings)

        XCTAssertNil(nextProvider.cachedDefaultAssets)
        XCTAssertTrue(try fetchList(from: nextProvider).isEmpty)
        XCTAssertNotNil(settings.defaultAssetsConfiguration)
    }

    func testFailedRemoteRefreshPreservesPersistedConfiguration() throws {
        let chain = ChainModelGenerator.generateChain(generatingAssets: 1, addressPrefix: 0)
        let id = try XCTUnwrap(chain.utilityChainAssetId())
        let settings = InMemorySettingsManager()
        let firstProvider = makeProvider(data: makeData(version: 1, ids: [id]), chains: [chain], settings: settings)
        _ = try fetchList(from: firstProvider)
        let factory = MockDataOperationFactoryProtocol()
        stub(factory) {
            $0.fetchData(from: url).thenReturn(BaseOperation.createWithError(CommonError.dataCorruption))
        }
        let provider = DefaultAssetsProvider(
            url: url,
            dataOperationFactory: factory,
            chainRegistry: MockChainRegistryProtocol().applyDefault(for: [chain]),
            settingsManager: settings,
            logger: Logger.shared
        )

        XCTAssertEqual(try execute(provider.createRefreshDefaultAssetsWrapper()).ids, [id])

        let nextProvider = makeProvider(data: Data(), chains: [chain], settings: settings)
        XCTAssertEqual(nextProvider.cachedDefaultAssets?.ids, [id])
        XCTAssertEqual(try fetchList(from: nextProvider).ids, [id])
    }

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
    func makeProvider(
        data: Data,
        chains: Set<ChainModel>,
        settings: SettingsManagerProtocol = InMemorySettingsManager()
    ) -> DefaultAssetsProvider {
        let dataOperationFactory = MockDataOperationFactoryProtocol()
        let chainRegistry = MockChainRegistryProtocol().applyDefault(for: chains)

        stub(dataOperationFactory) { stub in
            stub.fetchData(from: url).thenReturn(BaseOperation.createWithResult(data))
        }

        return DefaultAssetsProvider(
            url: url,
            dataOperationFactory: dataOperationFactory,
            chainRegistry: chainRegistry,
            settingsManager: settings,
            logger: Logger.shared
        )
    }

    func fetchList(from provider: DefaultAssetsProvider) throws -> DefaultAssetsList {
        try execute(provider.createDefaultAssetsWrapper())
    }

    func execute(_ wrapper: CompoundOperationWrapper<DefaultAssetsList>) throws -> DefaultAssetsList {
        let completed = expectation(description: "Default assets resolved")
        wrapper.targetOperation.completionBlock = { completed.fulfill() }
        OperationQueue().addOperations(wrapper.allOperations, waitUntilFinished: false)
        wait(for: [completed], timeout: Constants.defaultExpectationDuration)
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

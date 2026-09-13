import XCTest
@testable import novawallet
import Cuckoo
import Foundation_iOS
import Keystore_iOS
import Operation_iOS

final class TokensManageTests: XCTestCase {
    func testGroupsSectionsAndWrites() throws {
        // given
        let context = try TestContext.create()
        let view = MockTokensManageViewProtocol()
        let lists = Recorder<[TokensManageSection]>()
        let headerActions = Recorder<TokensManageHeaderActionViewModel>()
        let autoAdds = Recorder<Bool>()

        addTeardownBlock { context.defaultsGate.signal() }

        stub(view) { stub in
            when(stub.isSetup.get).thenReturn(false, true)
            when(stub.didReceive(sections: any())).then { lists.record($0) }
            when(stub.didReceive(headerAction: any())).then { headerActions.record($0) }
            when(stub.didReceive(autoAddTokens: any())).then { autoAdds.record($0) }
        }

        let presenter = context.createPresenter(for: view)

        // when
        let pendingLists = lists.expectation(forCount: 2)
        let autoAddResolved = autoAdds.expectation(forCount: 1)
        presenter.setup()
        wait(for: [pendingLists], timeout: 10.0)
        let listsWhilePending = lists.received

        let resolvedList = lists.expectation(forCount: 3)
        context.defaultsGate.signal()
        wait(for: [resolvedList], timeout: 10.0)
        let resolved = try XCTUnwrap(lists.received.dropFirst(2).first)

        let ethRoot = try XCTUnwrap(resolved.rootViewModels().first { $0.groupId == "ETH" })
        presenter.performExpand(for: ethRoot)
        let ethChildren = try XCTUnwrap(lists.received.dropFirst(3).first).childViewModels(in: "ETH")
        let snowbridgeChild = try XCTUnwrap(ethChildren.first { $0.chainAssetId == context.snowbridgeChainAssetId })

        let revealedList = lists.expectation(forCount: 5)
        presenter.performSwitch(for: snowbridgeChild, isOn: true)
        wait(for: [revealedList], timeout: 10.0)
        let statesAfterChildSwitch = try fetchStatesAfterWrites(in: context)

        let hiddenList = lists.expectation(forCount: 6)
        presenter.performSwitch(for: ethRoot, isOn: false)
        wait(for: [hiddenList], timeout: 10.0)
        let statesAfterRootSwitch = try fetchStatesAfterWrites(in: context)

        presenter.search(query: context.searchedChainName)
        let searched = try XCTUnwrap(lists.received.dropFirst(6).first)
        let searchedEthRoot = try XCTUnwrap(searched.rootViewModels().first { $0.groupId == "ETH" })
        let headerActionWhileHidden = headerActions.received.last

        let selectedList = lists.expectation(forCount: 8)
        presenter.performSelectAll()
        wait(for: [selectedList], timeout: 10.0)
        let statesAfterSelectAll = try fetchStatesAfterWrites(in: context)
        let headerActionAfterSelectAll = headerActions.received.last

        wait(for: [autoAddResolved], timeout: 10.0)
        let autoAddsBeforeChange = autoAdds.received
        let autoAddDisabled = autoAdds.expectation(forCount: 2)
        presenter.performAutoAddChange(to: false)
        wait(for: [autoAddDisabled], timeout: 10.0)
        let settingsAfterChange = try context.fetchSettings()

        var expectedStatesAfterSelectAll = statesAfterRootSwitch
        context.searchedChainAssetIds.forEach { expectedStatesAfterSelectAll[$0] = .visible }

        // then
        XCTAssertEqual(listsWhilePending, [[], []])
        XCTAssertEqual(resolved.map(\.kind), [.default, .others])
        XCTAssertEqual(resolved.map { $0.rootGroupIds() }, [["ETH", "DOT"], ["USDC"]])
        XCTAssertEqual(resolved.reduceToSwitches(), ["DOT": true, "ETH": true, "USDC": false])
        XCTAssertEqual(ethRoot.subtitle, "1 of 2 networks")
        XCTAssertEqual(Set(ethChildren.map(\.chainAssetId)), context.ethChainAssetIds)
        XCTAssertEqual(statesAfterChildSwitch, [context.snowbridgeChainAssetId: .visible])
        XCTAssertEqual(statesAfterRootSwitch, context.ethChainAssetIds.reduce(into: [:]) { $0[$1] = .hidden })
        XCTAssertEqual(
            try XCTUnwrap(lists.received.dropFirst(5).first).reduceToSwitches(),
            ["DOT": true, "ETH": false, "USDC": false]
        )
        XCTAssertEqual(searched.map(\.kind), [.results])
        XCTAssertEqual(searched.map { $0.rootGroupIds() }, [["ETH", "USDC"]])
        XCTAssertEqual(searchedEthRoot.subtitle, context.searchedChainName)
        XCTAssertEqual(headerActionWhileHidden, TokensManageHeaderActionViewModel(kind: .selectAll, isEnabled: true))
        XCTAssertEqual(statesAfterSelectAll, expectedStatesAfterSelectAll)
        XCTAssertEqual(headerActionAfterSelectAll, TokensManageHeaderActionViewModel(kind: .deselectAll, isEnabled: true))
        XCTAssertEqual(autoAddsBeforeChange, [true])
        XCTAssertEqual(
            settingsAfterChange,
            [MetaAccountSettingsLocal(metaId: context.wallet.metaId, autoAddTokensWithBalance: false)]
        )
    }
}

// MARK: - Private

private extension TokensManageTests {
    struct TestContext {
        let userStorageFacade: UserDataStorageTestFacade
        let operationQueue: OperationQueue
        let writer: AssetVisibilityWriter
        let interactor: TokensManageInteractor
        let wallet: MetaAccountModel
        let ethChainAssetIds: Set<ChainAssetId>
        let snowbridgeChainAssetId: ChainAssetId
        let searchedChainName: String
        let searchedChainAssetIds: Set<ChainAssetId>
        let defaultsGate: DispatchSemaphore

        static func create() throws -> TestContext {
            let userStorageFacade = UserDataStorageTestFacade()
            let operationQueue = OperationQueue()
            let subscriptionQueue = OperationQueue()
            subscriptionQueue.maxConcurrentOperationCount = 1
            let writeQueue = OperationQueue()
            writeQueue.maxConcurrentOperationCount = 1

            let polkadot = ChainModelGenerator.generateChain(
                assets: [
                    ChainModelGenerator.generateAssetWithId(0, symbol: "DOT"),
                    ChainModelGenerator.generateAssetWithId(1, symbol: "ETH")
                ],
                addressPrefix: 0
            )

            let assetHub = ChainModelGenerator.generateChain(
                assets: [
                    ChainModelGenerator.generateAssetWithId(0, symbol: "ETH-Snowbridge"),
                    ChainModelGenerator.generateAssetWithId(1, symbol: "USDC")
                ],
                defaultChainId: KnowChainId.polkadotAssetHub,
                addressPrefix: 0
            )

            let chainRegistry = MockChainRegistryProtocol().applyDefault(for: [polkadot, assetHub])
            let wallet = AccountGenerator.generateMetaAccount(generatingChainAccounts: 0)

            let selectedWalletSettings = SelectedWalletSettings(
                storageFacade: userStorageFacade,
                operationQueue: operationQueue
            )

            selectedWalletSettings.save(value: wallet)

            let assetVisibilitySubscriptionFactory = AssetVisibilityLocalSubscriptionFactory(
                chainRegistry: chainRegistry,
                storageFacade: userStorageFacade,
                operationManager: OperationManager(operationQueue: subscriptionQueue),
                logger: Logger.shared
            )

            let writer = AssetVisibilityWriter(
                storageFacade: userStorageFacade,
                writeQueue: writeQueue,
                workQueue: operationQueue,
                logger: Logger.shared
            )

            let defaultsGate = DispatchSemaphore(value: 0)

            let config = """
            {
              "defaultAssets": [
                { "chainId": "\(polkadot.chainId)", "assetId": 1 },
                { "chainId": "\(polkadot.chainId)", "assetId": 0 }
              ]
            }
            """

            let dataOperationFactory = MockDataOperationFactoryProtocol()

            stub(dataOperationFactory) { stub in
                stub.fetchData(from: any()).thenReturn(
                    ClosureOperation<Data> {
                        defaultsGate.wait()
                        return Data(config.utf8)
                    }
                )
            }

            let interactor = TokensManageInteractor(
                chainRegistry: chainRegistry,
                selectedWalletSettings: selectedWalletSettings,
                settingsManager: InMemorySettingsManager(),
                assetVisibilitySubscriptionFactory: assetVisibilitySubscriptionFactory,
                visibilityWriter: writer,
                settingsRepository: AssetVisibilityRepositoryFactory.createSettingsRepository(
                    for: wallet.metaId,
                    using: userStorageFacade
                ),
                defaultAssetsProvider: DefaultAssetsProvider(
                    url: Constants.dummyURL,
                    dataOperationFactory: dataOperationFactory,
                    logger: Logger.shared
                ),
                operationQueue: OperationQueue(),
                settingsSaveQueue: writeQueue,
                logger: Logger.shared
            )

            let ethChainAssetIds = Set(
                [polkadot, assetHub]
                    .flatMap { $0.chainAssets() }
                    .filter { $0.asset.symbol.hasPrefix("ETH") }
                    .map(\.chainAssetId)
            )

            return TestContext(
                userStorageFacade: userStorageFacade,
                operationQueue: operationQueue,
                writer: writer,
                interactor: interactor,
                wallet: wallet,
                ethChainAssetIds: ethChainAssetIds,
                snowbridgeChainAssetId: ChainAssetId(chainId: assetHub.chainId, assetId: 0),
                searchedChainName: assetHub.name,
                searchedChainAssetIds: Set(assetHub.chainAssets().map(\.chainAssetId)),
                defaultsGate: defaultsGate
            )
        }

        func createPresenter(for view: TokensManageViewProtocol) -> TokensManagePresenter {
            let viewModelFactory = TokensManageViewModelFactory(
                quantityFormater: NumberFormatter.positiveQuantity.localizableResource(),
                assetIconViewModelFactory: AssetIconViewModelFactory(),
                networkViewModelFactory: NetworkViewModelFactory()
            )

            let presenter = TokensManagePresenter(
                interactor: interactor,
                wireframe: MockTokensManageWireframeProtocol(),
                viewModelFactory: viewModelFactory,
                localizationManager: LocalizationManager.shared
            )

            presenter.view = view
            interactor.presenter = presenter

            return presenter
        }

        func fetchStates() throws -> [ChainAssetId: AssetVisibilityState] {
            let repository = AssetVisibilityRepositoryFactory.createVisibilityRepository(
                for: wallet.metaId,
                using: userStorageFacade
            )

            return try fetchAll(from: repository).reduce(into: [:]) { $0[$1.chainAssetId] = $1.state }
        }

        func fetchSettings() throws -> [MetaAccountSettingsLocal] {
            let repository = AssetVisibilityRepositoryFactory.createSettingsRepository(
                for: wallet.metaId,
                using: userStorageFacade
            )

            return try fetchAll(from: repository)
        }

        func fetchAll<T>(from repository: AnyDataProviderRepository<T>) throws -> [T] {
            let fetchOperation = repository.fetchAllOperation(with: RepositoryFetchOptions())
            operationQueue.addOperations([fetchOperation], waitUntilFinished: true)

            return try fetchOperation.extractNoCancellableResultData()
        }
    }

    final class Recorder<Value> {
        private(set) var received: [Value] = []
        private var expectations: [Int: XCTestExpectation] = [:]

        func record(_ value: Value) {
            received.append(value)
            expectations[received.count]?.fulfill()
        }

        func expectation(forCount count: Int) -> XCTestExpectation {
            let expectation = XCTestExpectation()
            expectations[count] = expectation
            return expectation
        }
    }

    func fetchStatesAfterWrites(in context: TestContext) throws -> [ChainAssetId: AssetVisibilityState] {
        let expectation = XCTestExpectation()

        context.writer.enqueueBarrier(callbackIn: .main) {
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 10.0)

        return try context.fetchStates()
    }
}

private extension TokensManageSection {
    func rootGroupIds() -> [String] {
        items.compactMap { item in
            if case let .root(viewModel) = item {
                return viewModel.groupId
            } else {
                return nil
            }
        }
    }
}

private extension Array where Element == TokensManageSection {
    func rootViewModels() -> [TokensManageRootViewModel] {
        flatMap(\.items).compactMap { item in
            if case let .root(viewModel) = item {
                return viewModel
            } else {
                return nil
            }
        }
    }

    func childViewModels(in groupId: String) -> [TokensManageChildViewModel] {
        flatMap(\.items).compactMap { item in
            if case let .child(viewModel) = item, viewModel.groupId == groupId {
                return viewModel
            } else {
                return nil
            }
        }
    }

    func reduceToSwitches() -> [String: Bool] {
        rootViewModels().reduce(into: [:]) { $0[$1.groupId] = $1.isOn }
    }
}

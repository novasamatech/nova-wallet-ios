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
        let lists = ListRecorder()

        addTeardownBlock { context.defaultsGate.signal() }

        stub(view) { stub in
            when(stub.isSetup.get).thenReturn(false, true)
            when(stub.didReceive(viewModels: any())).then { lists.record($0) }
        }

        let presenter = context.createPresenter(for: view)

        // when
        let pendingLists = lists.expectation(forListCount: 2)
        presenter.setup()
        wait(for: [pendingLists], timeout: 10.0)
        let listsWhilePending = lists.received

        let resolvedList = lists.expectation(forListCount: 3)
        context.defaultsGate.signal()
        wait(for: [resolvedList], timeout: 10.0)
        let resolved = lists.received[2]

        let ethViewModel = try XCTUnwrap(resolved.first { $0.symbol == "ETH" })
        let hiddenList = lists.expectation(forListCount: 4)
        presenter.performSwitch(for: ethViewModel, enabled: false)
        wait(for: [hiddenList], timeout: 10.0)
        let statesAfterSwitch = try fetchStatesAfterWrites(in: context)

        // then
        XCTAssertEqual(listsWhilePending, [[], []])
        XCTAssertEqual(resolved.reduceToSwitches(), ["DOT": true, "ETH": true, "USDC": false])
        XCTAssertEqual(lists.received[3].reduceToSwitches(), ["DOT": true, "ETH": false, "USDC": false])
        XCTAssertEqual(statesAfterSwitch, context.ethChainAssetIds.reduce(into: [:]) { $0[$1] = .hidden })
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

            let hydration = ChainModelGenerator.generateChain(
                assets: [
                    ChainModelGenerator.generateAssetWithId(0, symbol: "ETH"),
                    ChainModelGenerator.generateAssetWithId(1, symbol: "ETH-Snowbridge"),
                    ChainModelGenerator.generateAssetWithId(2, symbol: "USDC")
                ],
                addressPrefix: 63
            )

            let chainRegistry = MockChainRegistryProtocol().applyDefault(for: [polkadot, hydration])
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
                { "chainId": "\(polkadot.chainId)", "assetId": 0 },
                { "chainId": "\(polkadot.chainId)", "assetId": 1 }
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
                logger: Logger.shared
            )

            let ethChainAssetIds = Set(
                [polkadot, hydration]
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
                defaultsGate: defaultsGate
            )
        }

        func createPresenter(for view: TokensManageViewProtocol) -> TokensManagePresenter {
            let viewModelFactory = TokensManageViewModelFactory(
                quantityFormater: NumberFormatter.positiveQuantity.localizableResource(),
                assetIconViewModelFactory: AssetIconViewModelFactory()
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

            let fetchOperation = repository.fetchAllOperation(with: RepositoryFetchOptions())
            operationQueue.addOperations([fetchOperation], waitUntilFinished: true)

            return try fetchOperation.extractNoCancellableResultData().reduce(into: [:]) {
                $0[$1.chainAssetId] = $1.state
            }
        }
    }

    final class ListRecorder {
        private(set) var received: [[TokensManageViewModel]] = []
        private var expectations: [Int: XCTestExpectation] = [:]

        func record(_ list: [TokensManageViewModel]) {
            received.append(list)
            expectations[received.count]?.fulfill()
        }

        func expectation(forListCount count: Int) -> XCTestExpectation {
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

private extension Array where Element == TokensManageViewModel {
    func reduceToSwitches() -> [String: Bool] {
        reduce(into: [:]) { $0[$1.symbol] = $1.isOn }
    }
}

import XCTest
@testable import novawallet
import Cuckoo
import Operation_iOS

final class AutoAddTokensServiceTests: XCTestCase {
    func testPositiveBalanceRevealsUndecidedAndPromotesFilterHides() throws {
        // given
        let context = try TestContext.create()
        let deliveries = DeliveryTracker()

        try context.store(states: [1: .hiddenUntilBalance, 2: .hidden])

        // when
        context.service.setup()

        let initialSnapshots = [deliveries.nextBalances(), deliveries.nextSettings()]
        try context.track(with: deliveries)
        wait(for: initialSnapshots, timeout: 10.0)

        let heldBalances = deliveries.nextBalances()
        try context.store(balancesFor: [0, 1, 2])
        wait(for: [heldBalances], timeout: 10.0)
        let statesAfterBalances = try fetchStatesAfterWrites(in: context)

        let disabledSetting = deliveries.nextSettings()
        try context.store(autoAddTokensWithBalance: false)
        wait(for: [disabledSetting], timeout: 10.0)

        let ignoredBalance = deliveries.nextBalances()
        try context.store(balancesFor: [3])
        wait(for: [ignoredBalance], timeout: 10.0)
        let statesWhileDisabled = try fetchStatesAfterWrites(in: context)

        let enabledSetting = deliveries.nextSettings()
        try context.store(autoAddTokensWithBalance: true)
        wait(for: [enabledSetting], timeout: 10.0)
        let statesAfterEnabled = try fetchStatesAfterWrites(in: context)

        // then
        XCTAssertEqual(statesAfterBalances, context.states([0: .visible, 1: .visible, 2: .hidden]))
        XCTAssertEqual(statesWhileDisabled, statesAfterBalances)
        XCTAssertEqual(statesAfterEnabled, context.states([0: .visible, 1: .visible, 2: .hidden, 3: .visible]))
    }
}

// MARK: - Private

private extension AutoAddTokensServiceTests {
    struct TestContext {
        let substrateStorageFacade: SubstrateStorageTestFacade
        let userStorageFacade: UserDataStorageTestFacade
        let operationQueue: OperationQueue
        let walletLocalSubscriptionFactory: WalletLocalSubscriptionFactory
        let assetVisibilitySubscriptionFactory: AssetVisibilityLocalSubscriptionFactory
        let writer: AssetVisibilityWriter
        let service: AutoAddTokensService
        let chain: ChainModel
        let wallet: MetaAccountModel

        static func create() throws -> TestContext {
            let substrateStorageFacade = SubstrateStorageTestFacade()
            let userStorageFacade = UserDataStorageTestFacade()
            let operationQueue = OperationQueue()
            let subscriptionQueue = OperationQueue()
            subscriptionQueue.maxConcurrentOperationCount = 1
            let writeQueue = OperationQueue()
            writeQueue.maxConcurrentOperationCount = 1

            let chain = ChainModelGenerator.generateChain(generatingAssets: 4, addressPrefix: 42)
            let chainRegistry = MockChainRegistryProtocol().applyDefault(for: [chain])
            let wallet = AccountGenerator.generateMetaAccount(generatingChainAccounts: 0)
            let operationManager = OperationManager(operationQueue: subscriptionQueue)

            let walletLocalSubscriptionFactory = WalletLocalSubscriptionFactory(
                chainRegistry: chainRegistry,
                storageFacade: substrateStorageFacade,
                operationManager: operationManager,
                logger: Logger.shared
            )

            let assetVisibilitySubscriptionFactory = AssetVisibilityLocalSubscriptionFactory(
                chainRegistry: chainRegistry,
                storageFacade: userStorageFacade,
                operationManager: operationManager,
                logger: Logger.shared
            )

            let writer = AssetVisibilityWriter(
                storageFacade: userStorageFacade,
                writeQueue: writeQueue,
                workQueue: operationQueue,
                logger: Logger.shared
            )

            let dataOperationFactory = MockDataOperationFactoryProtocol()

            stub(dataOperationFactory) { stub in
                stub.fetchData(from: any()).thenReturn(
                    BaseOperation.createWithError(BaseOperationError.unexpectedDependentResult)
                )
            }

            let service = AutoAddTokensService(
                selectedMetaAccount: wallet,
                chainRegistry: chainRegistry,
                walletLocalSubscriptionFactory: walletLocalSubscriptionFactory,
                assetVisibilitySubscriptionFactory: assetVisibilitySubscriptionFactory,
                visibilityWriter: writer,
                defaultAssetsProvider: DefaultAssetsProvider(
                    url: Constants.dummyURL,
                    dataOperationFactory: dataOperationFactory,
                    logger: Logger.shared
                ),
                operationQueue: OperationQueue(),
                logger: Logger.shared
            )

            return TestContext(
                substrateStorageFacade: substrateStorageFacade,
                userStorageFacade: userStorageFacade,
                operationQueue: operationQueue,
                walletLocalSubscriptionFactory: walletLocalSubscriptionFactory,
                assetVisibilitySubscriptionFactory: assetVisibilitySubscriptionFactory,
                writer: writer,
                service: service,
                chain: chain,
                wallet: wallet
            )
        }

        func states(_ states: [AssetModel.Id: AssetVisibilityState]) -> [ChainAssetId: AssetVisibilityState] {
            states.reduce(into: [:]) { $0[ChainAssetId(chainId: chain.chainId, assetId: $1.key)] = $1.value }
        }

        func track(with deliveries: DeliveryTracker) throws {
            deliveries.track(
                balancesProvider: try walletLocalSubscriptionFactory.getAllBalancesProvider(),
                settingsProvider: assetVisibilitySubscriptionFactory.getSettingsProvider(for: wallet.metaId)
            )
        }

        func store(states: [AssetModel.Id: AssetVisibilityState]) throws {
            let rows = states.map {
                AssetVisibilityLocal(metaId: wallet.metaId, chainId: chain.chainId, assetId: $0.key, state: $0.value)
            }

            try store(
                rows,
                to: AssetVisibilityRepositoryFactory.createVisibilityRepository(for: wallet.metaId, using: userStorageFacade)
            )
        }

        func store(balancesFor assetIds: [AssetModel.Id]) throws {
            let accountId = try XCTUnwrap(wallet.fetch(for: chain.accountRequest())?.accountId)

            let balances = assetIds.map {
                AssetBalance(
                    chainAssetId: ChainAssetId(chainId: chain.chainId, assetId: $0),
                    accountId: accountId,
                    freeInPlank: 100,
                    reservedInPlank: 0,
                    frozenInPlank: 0,
                    edCountMode: .basedOnFree,
                    transferrableMode: .regular,
                    blocked: false
                )
            }

            try store(
                balances,
                to: SubstrateRepositoryFactory(storageFacade: substrateStorageFacade).createAssetBalanceRepository()
            )
        }

        func store(autoAddTokensWithBalance: Bool) throws {
            let settings = MetaAccountSettingsLocal(
                metaId: wallet.metaId,
                autoAddTokensWithBalance: autoAddTokensWithBalance
            )

            try store(
                [settings],
                to: AssetVisibilityRepositoryFactory.createSettingsRepository(for: wallet.metaId, using: userStorageFacade)
            )
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

        private func store<T: Identifiable>(_ models: [T], to repository: AnyDataProviderRepository<T>) throws {
            let saveOperation = repository.saveOperation({ models }, { [] })
            operationQueue.addOperations([saveOperation], waitUntilFinished: true)
            try saveOperation.extractNoCancellableResultData()
        }
    }

    final class DeliveryTracker {
        private var balancesExpectation: XCTestExpectation?
        private var settingsExpectation: XCTestExpectation?

        func track(
            balancesProvider: StreamableProvider<AssetBalance>,
            settingsProvider: StreamableProvider<MetaAccountSettingsLocal>
        ) {
            balancesProvider.addObserver(
                self,
                deliverOn: .main,
                executing: { [weak self] _ in self?.balancesExpectation?.fulfill() },
                failing: { _ in },
                options: .allNonblocking()
            )

            settingsProvider.addObserver(
                self,
                deliverOn: .main,
                executing: { [weak self] _ in self?.settingsExpectation?.fulfill() },
                failing: { _ in },
                options: .allNonblocking()
            )
        }

        func nextBalances() -> XCTestExpectation {
            let expectation = XCTestExpectation()
            balancesExpectation = expectation
            return expectation
        }

        func nextSettings() -> XCTestExpectation {
            let expectation = XCTestExpectation()
            settingsExpectation = expectation
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

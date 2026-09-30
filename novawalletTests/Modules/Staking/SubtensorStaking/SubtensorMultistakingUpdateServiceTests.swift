import XCTest
@testable import novawallet
import BigInt
import Cuckoo
import Operation_iOS

final class SubtensorMultistakingUpdateServiceTests: XCTestCase {
    let walletId = "subtensor-test-wallet"
    let accountId = Data(repeating: 1, count: 32)
    let otherAccountId = Data(repeating: 9, count: 32)

    func testOwnStakingChangeResyncsTheDashboardRowWithTheBestRecommendedApy() throws {
        let context = try makeContext { .createWithResult(Decimal(string: "0.2578")) }

        resyncAfterOwnStakingChange(context, stake: 2_000_000_000) { $0.maxApy == Decimal(string: "0.2578") }

        let item = try fetchDashboardItem(of: context)

        XCTAssertEqual(item.stake, BigUInt(2_000_000_000))
        XCTAssertEqual(item.maxApy, Decimal(string: "0.2578"))
    }

    func testFailedMaxApyFetchAfterARelaunchShowsNoRateAndKeepsTheStake() throws {
        let storageFacade = SubstrateStorageTestFacade()

        let firstLaunch = try makeContext(storageFacade: storageFacade) { .createWithResult(Decimal(string: "0.2578")) }

        resyncAfterOwnStakingChange(firstLaunch, stake: 2_000_000_000) { $0.maxApy == Decimal(string: "0.2578") }

        let relaunch = try makeContext(storageFacade: storageFacade) {
            .createWithError(BittensorApiError.datasetUnavailable(requestId: nil))
        }

        resyncAfterOwnStakingChange(relaunch, stake: 2_000_000_000) { $0.maxApy == nil }

        let item = try fetchDashboardItem(of: relaunch)

        XCTAssertEqual(item.stake, BigUInt(2_000_000_000))
        XCTAssertNil(item.maxApy)
    }

    func testStakeIsPersistedWhileTheMaxApyIsStillResolving() throws {
        let storageFacade = SubstrateStorageTestFacade()

        let firstLaunch = try makeContext(storageFacade: storageFacade) { .createWithResult(Decimal(string: "0.40")) }

        resyncAfterOwnStakingChange(firstLaunch, stake: 2_000_000_000) { $0.maxApy == Decimal(string: "0.40") }

        let relaunch = try makeContext(storageFacade: storageFacade) {
            CompoundOperationWrapper(targetOperation: AsyncClosureOperation<Decimal?>(operationClosure: { _ in }))
        }

        resyncAfterOwnStakingChange(relaunch, stake: 3_000_000_000) { $0.stake == BigUInt(3_000_000_000) }

        let item = try fetchDashboardItem(of: relaunch)

        XCTAssertEqual(item.stake, BigUInt(3_000_000_000))
        XCTAssertEqual(item.maxApy, Decimal(string: "0.40"))
    }

    func testOnlyTheOwnAccountAndChainAssetChangeResyncs() throws {
        let context = try makeContext()
        let otherChainAssetId = ChainAssetId(chainId: context.chainAsset.chain.chainId, assetId: 1)

        stub(context.fetchFactory) { stub in
            when(stub.createStateWrapper(for: any())).then { _ in
                CompoundOperationWrapper.createWithResult(Self.stakingState(stake: 2_000_000_000))
            }
        }

        context.service.setup()

        context.eventCenter.notify(
            with: SubtensorStakingChanged(chainAssetId: context.chainAsset.chainAssetId, accountId: otherAccountId)
        )

        context.eventCenter.notify(with: SubtensorStakingChanged(chainAssetId: otherChainAssetId, accountId: accountId))

        drainEvents(of: context)

        verify(context.fetchFactory, never()).createStateWrapper(for: any())

        context.eventCenter.notify(
            with: SubtensorStakingChanged(chainAssetId: context.chainAsset.chainAssetId, accountId: accountId)
        )

        drainEvents(of: context)

        context.service.throttle()

        verify(context.fetchFactory, times(1)).createStateWrapper(for: equal(to: accountId))
    }

    private func resyncAfterOwnStakingChange(
        _ context: Context,
        stake: BigUInt,
        until isPersisted: @escaping (Multistaking.DashboardItem) -> Bool
    ) {
        stub(context.fetchFactory) { stub in
            when(stub.createStateWrapper(for: any())).then { _ in
                CompoundOperationWrapper.createWithResult(Self.stakingState(stake: stake))
            }
        }

        context.service.setup()

        let persisted = expectation(description: "dashboard row persisted")
        persisted.assertForOverFulfill = false

        let walletId = walletId

        context.service.subscribeSyncState(self, queue: context.observerQueue) { wasSyncing, isSyncing in
            guard
                wasSyncing,
                !isSyncing,
                let item = Self.findDashboardItem(walletId: walletId, context: context),
                isPersisted(item) else {
                return
            }

            persisted.fulfill()
        }

        context.eventCenter.notify(
            with: SubtensorStakingChanged(chainAssetId: context.chainAsset.chainAssetId, accountId: accountId)
        )

        wait(for: [persisted], timeout: 10)

        context.service.unsubscribeSyncState(self)
        context.service.throttle()
    }

    private func drainEvents(of context: Context) {
        context.eventQueue.sync {}
        context.service.workingQueue.sync {}
    }

    private struct Context {
        let service: SubtensorMultistakingUpdateService
        let fetchFactory: MockSubtensorStakeStateFetchFactoryProtocol
        let eventCenter: EventCenter
        let eventQueue: DispatchQueue
        let observerQueue: DispatchQueue
        let repositoryFactory: MultistakingRepositoryFactory
        let chainAsset: ChainAsset
    }

    private func makeContext(
        storageFacade: StorageFacadeProtocol = SubstrateStorageTestFacade(),
        maxApyWrapper: @escaping () -> CompoundOperationWrapper<Decimal?> = { .createWithResult(nil) }
    ) throws -> Context {
        let repositoryFactory = MultistakingRepositoryFactory(storageFacade: storageFacade)
        let fetchFactory = MockSubtensorStakeStateFetchFactoryProtocol()
        let maxApyProvider = MockSubtensorMaxApyProviderProtocol()
        let eventQueue = DispatchQueue(label: "test.subtensor.multistaking.events")
        let eventCenter = EventCenter(syncQueue: eventQueue)
        let chainAsset = Self.subtensorChainAsset()

        stub(maxApyProvider) { stub in
            when(stub.createMaxApyWrapper()).then {
                maxApyWrapper()
            }
        }

        let service = SubtensorMultistakingUpdateService(
            walletId: walletId,
            accountId: accountId,
            chainAsset: chainAsset,
            stakingType: .subtensor,
            dashboardRepository: repositoryFactory.createSubtensorRepository(),
            stakeStateFetchFactory: fetchFactory,
            cacheRepository: SubstrateRepositoryFactory(storageFacade: storageFacade).createChainStorageItemRepository(),
            connection: TestJSONRPCEngine(),
            runtimeService: RuntimeCodingServiceStub(
                factory: try RuntimeCodingServiceStub.createBittensorCodingFactory()
            ),
            operationQueue: OperationQueue(),
            workingQueue: DispatchQueue(label: "test.subtensor.multistaking"),
            logger: Logger.shared,
            maxApyProvider: maxApyProvider,
            eventCenter: eventCenter
        )

        return Context(
            service: service,
            fetchFactory: fetchFactory,
            eventCenter: eventCenter,
            eventQueue: eventQueue,
            observerQueue: DispatchQueue(label: "test.subtensor.multistaking.observer"),
            repositoryFactory: repositoryFactory,
            chainAsset: chainAsset
        )
    }

    private func fetchDashboardItem(of context: Context) throws -> Multistaking.DashboardItem {
        try XCTUnwrap(Self.findDashboardItem(walletId: walletId, context: context))
    }

    private static func findDashboardItem(
        walletId: MetaAccountModel.Id,
        context: Context
    ) -> Multistaking.DashboardItem? {
        let repository = context.repositoryFactory.createDashboardRepository(for: walletId)
        let fetchOperation = repository.fetchAllOperation(with: RepositoryFetchOptions())

        OperationQueue().addOperations([fetchOperation], waitUntilFinished: true)

        let items = try? fetchOperation.extractNoCancellableResultData()

        return items?.first { $0.stakingOption.option.chainAssetId == context.chainAsset.chainAssetId }
    }

    private static func stakingState(stake: BigUInt) -> Multistaking.SubtensorStakingState {
        Multistaking.SubtensorStakingState(
            positions: [
                SubtensorStakingPosition(
                    hotkey: Data(repeating: 2, count: 32),
                    netuid: SubtensorStakingPallet.rootNetuid,
                    stakeAlpha: stake,
                    hotkeyEmissionPerTempo: 0,
                    totalHotkeyAlpha: nil,
                    isRegistered: true
                )
            ],
            prices: [:]
        )
    }

    private static func subtensorChainAsset() -> ChainAsset {
        let asset = AssetModel(
            assetId: AssetModel.utilityAssetId,
            icon: nil,
            name: "Bittensor",
            symbol: "TAO",
            precision: 9,
            priceId: nil,
            stakings: [.subtensor],
            type: nil,
            typeExtras: nil,
            buyProviders: nil,
            sellProviders: nil,
            source: .remote
        )

        let chain = ChainModelGenerator.generateChain(
            assets: [asset],
            defaultChainId: KnowChainId.bittensor,
            addressPrefix: 42
        )

        return ChainAsset(chain: chain, asset: asset)
    }
}

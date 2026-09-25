import XCTest
@testable import novawallet
import BigInt
import Cuckoo
import Operation_iOS

final class SubtensorMultistakingUpdateServiceTests: XCTestCase {
    let walletId = "subtensor-test-wallet"
    let accountId = Data(repeating: 1, count: 32)
    let otherAccountId = Data(repeating: 9, count: 32)

    func testOwnStakingChangeResyncsTheDashboardRowWithTheHeadlineRate() throws {
        let context = try makeContext()

        stub(context.fetchFactory) { stub in
            when(stub.createStateWrapper(for: any())).then { _ in
                CompoundOperationWrapper.createWithResult(Self.stakingState(stake: 2_000_000_000))
            }
        }

        context.service.setup()

        let persisted = expectation(description: "dashboard row persisted")
        persisted.assertForOverFulfill = false

        context.service.subscribeSyncState(self, queue: nil) { wasSyncing, isSyncing in
            if wasSyncing, !isSyncing {
                persisted.fulfill()
            }
        }

        context.eventCenter.notify(
            with: SubtensorStakingChanged(chainAssetId: context.chainAsset.chainAssetId, accountId: accountId)
        )

        wait(for: [persisted], timeout: 10)

        context.service.unsubscribeSyncState(self)
        context.service.throttle()

        let item = try fetchDashboardItem(using: context.repositoryFactory, chainAsset: context.chainAsset)

        XCTAssertEqual(item.stake, BigUInt(2_000_000_000))
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

    private func drainEvents(of context: Context) {
        context.eventQueue.sync {}
        context.service.workingQueue.sync {}
    }

    private struct Context {
        let service: SubtensorMultistakingUpdateService
        let fetchFactory: MockSubtensorStakeStateFetchFactoryProtocol
        let eventCenter: EventCenter
        let eventQueue: DispatchQueue
        let repositoryFactory: MultistakingRepositoryFactory
        let chainAsset: ChainAsset
    }

    private func makeContext() throws -> Context {
        let storageFacade = SubstrateStorageTestFacade()
        let repositoryFactory = MultistakingRepositoryFactory(storageFacade: storageFacade)
        let fetchFactory = MockSubtensorStakeStateFetchFactoryProtocol()
        let configProvider = MockSubtensorEarnConfigProviderProtocol()
        let eventQueue = DispatchQueue(label: "test.subtensor.multistaking.events")
        let eventCenter = EventCenter(syncQueue: eventQueue)
        let chainAsset = Self.subtensorChainAsset()

        stub(configProvider) { stub in
            when(stub.createConfigWrapper()).then {
                CompoundOperationWrapper.createWithResult(Self.earnConfig())
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
            earnConfigProvider: configProvider,
            eventCenter: eventCenter
        )

        return Context(
            service: service,
            fetchFactory: fetchFactory,
            eventCenter: eventCenter,
            eventQueue: eventQueue,
            repositoryFactory: repositoryFactory,
            chainAsset: chainAsset
        )
    }

    private func fetchDashboardItem(
        using repositoryFactory: MultistakingRepositoryFactory,
        chainAsset: ChainAsset
    ) throws -> Multistaking.DashboardItem {
        let repository = repositoryFactory.createDashboardRepository(for: walletId)
        let fetchOperation = repository.fetchAllOperation(with: RepositoryFetchOptions())

        OperationQueue().addOperations([fetchOperation], waitUntilFinished: true)

        let items = try fetchOperation.extractNoCancellableResultData()

        return try XCTUnwrap(items.first { $0.stakingOption.option.chainAssetId == chainAsset.chainAssetId })
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

    private static func earnConfig() -> SubtensorEarnConfig {
        SubtensorEarnConfig(
            version: 1,
            entry: nil,
            headlineMaxAnnualRate: Decimal(string: "0.40"),
            preferredRootValidator: nil,
            logoBaseUrl: nil,
            subnets: [:],
            invalidEntries: []
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

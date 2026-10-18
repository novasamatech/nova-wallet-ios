import XCTest
@testable import novawallet
import BigInt
import Cuckoo
import Operation_iOS

final class StakingDashboardSubtensorMapperTests: XCTestCase {
    let walletId = "subtensor-test-wallet"
    let otherChainId = "91b171bb158e2d3848fa23a9f1c25182fb8e20313b2c1eb49219da7a70ce90c3"

    func testPartWithPositionsWritesStakeAndActiveIndependentState() throws {
        let repositoryFactory = MultistakingRepositoryFactory(storageFacade: SubstrateStorageTestFacade())

        let state = Self.stakingState(stakeAlpha: 57_816_438)

        try saveSubtensorPart(state: state, walletId: walletId, using: repositoryFactory)

        let item = try fetchDashboardItem(for: subtensorOption(), walletId: walletId, using: repositoryFactory)

        XCTAssertEqual(item.stake, BigUInt(57_816_438))
        XCTAssertEqual(item.onchainState, .activeIndependent)
        XCTAssertEqual(item.state, .active)
    }

    func testPartWithoutPositionsWritesNilStakeAndState() throws {
        let repositoryFactory = MultistakingRepositoryFactory(storageFacade: SubstrateStorageTestFacade())

        let state = Multistaking.SubtensorStakingState(positions: [], prices: [0: 1_000_000_000])

        try saveSubtensorPart(state: state, walletId: walletId, using: repositoryFactory)

        let item = try fetchDashboardItem(for: subtensorOption(), walletId: walletId, using: repositoryFactory)

        XCTAssertNil(item.stake)
        XCTAssertNil(item.onchainState)
        XCTAssertNil(item.state)
    }

    func testPartWritesItsMaxApy() throws {
        let repositoryFactory = MultistakingRepositoryFactory(storageFacade: SubstrateStorageTestFacade())

        try saveSubtensorPart(
            state: Self.stakingState(stakeAlpha: 57_816_438),
            maxApy: .replace(Decimal(string: "0.40")),
            walletId: walletId,
            using: repositoryFactory
        )

        let item = try fetchDashboardItem(for: subtensorOption(), walletId: walletId, using: repositoryFactory)

        XCTAssertEqual(item.maxApy, Decimal(string: "0.40"))
    }

    func testPartReplacingMaxApyWithNoneClearsTheStoredValue() throws {
        let repositoryFactory = MultistakingRepositoryFactory(storageFacade: SubstrateStorageTestFacade())
        let state = Self.stakingState(stakeAlpha: 57_816_438)

        let stored = Decimal(string: "0.40")

        try saveSubtensorPart(state: state, maxApy: .replace(stored), walletId: walletId, using: repositoryFactory)
        try saveSubtensorPart(state: state, maxApy: .replace(nil), walletId: walletId, using: repositoryFactory)

        let item = try fetchDashboardItem(for: subtensorOption(), walletId: walletId, using: repositoryFactory)

        XCTAssertNil(item.maxApy)
    }

    func testOffchainSyncOmittingSubtensorOptionKeepsOnchainRowWithoutApy() throws {
        let repositoryFactory = MultistakingRepositoryFactory(storageFacade: SubstrateStorageTestFacade())
        let operationQueue = OperationQueue()

        let wallet = AccountGenerator.generateMetaAccount()
        let chainAsset = Self.subtensorChainAsset()

        try saveSubtensorPart(
            state: Self.stakingState(stakeAlpha: 1_000_000_000),
            walletId: wallet.metaId,
            using: repositoryFactory
        )

        var capturedRequests: [Multistaking.OffchainRequest] = []

        let unrelatedChainId = otherChainId
        let offchainFactory = MockMultistakingOffchainOperationFactoryProtocol()

        stub(offchainFactory) { stub in
            when(stub.createWrapper(for: any())).then { request in
                capturedRequests.append(request)

                let unrelatedStaking = Multistaking.OffchainStaking(
                    chainId: unrelatedChainId,
                    stakingType: .relaychain,
                    maxApy: 0.17,
                    state: .active,
                    totalRewards: nil
                )

                return CompoundOperationWrapper.createWithResult([unrelatedStaking])
            }
        }

        let providerFactory = MultistakingProviderFactory(
            repositoryFactory: repositoryFactory,
            operationQueue: operationQueue
        )

        let service = OffchainMultistakingUpdateService(
            wallet: wallet,
            accountResolveProvider: providerFactory.createResolvedAccountsProvider(),
            dashboardRepository: repositoryFactory.createOffchainRepository(),
            operationFactory: offchainFactory,
            workingQueue: DispatchQueue.global(),
            operationQueue: operationQueue,
            syncDelay: 0
        )

        service.setup()

        let syncCompletion = XCTestExpectation(description: "offchain sync completed")
        syncCompletion.assertForOverFulfill = false

        service.subscribeSyncState(self, queue: nil) { oldState, newState in
            if oldState, !newState {
                syncCompletion.fulfill()
            }
        }

        service.apply(newChainAssets: [chainAsset])

        wait(for: [syncCompletion], timeout: 10)

        service.unsubscribeSyncState(self)
        service.throttle()

        let request = try XCTUnwrap(capturedRequests.first)

        XCTAssertTrue(
            request.stateFilters.contains { filter in
                filter.chainAsset.chainAssetId == chainAsset.chainAssetId &&
                    filter.stakingTypes.contains(.subtensor)
            }
        )

        let allItems = try fetchAllDashboardItems(walletId: wallet.metaId, using: repositoryFactory)
        let subtensorItems = allItems.filter { $0.stakingOption.option == subtensorOption() }
        let unrelatedItems = allItems.filter { $0.stakingOption.option.chainAssetId.chainId == otherChainId }

        XCTAssertEqual(unrelatedItems.first?.maxApy, 0.17)
        XCTAssertEqual(subtensorItems.count, 1)
        XCTAssertEqual(subtensorItems.first?.stake, BigUInt(1_000_000_000))
        XCTAssertEqual(subtensorItems.first?.onchainState, .activeIndependent)
        XCTAssertNil(subtensorItems.first?.maxApy)
    }

    private static func stakingState(stakeAlpha: BigUInt) -> Multistaking.SubtensorStakingState {
        Multistaking.SubtensorStakingState(
            positions: [
                SubtensorStakingPosition(
                    hotkey: Data(repeating: 2, count: 32),
                    netuid: 0,
                    stakeAlpha: stakeAlpha,
                    hotkeyEmissionPerTempo: 0,
                    totalHotkeyAlpha: nil,
                    isRegistered: true
                )
            ],
            prices: [0: 1_000_000_000]
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

    private func subtensorOption() -> Multistaking.Option {
        Multistaking.Option(
            chainAssetId: ChainAssetId(chainId: KnowChainId.bittensor, assetId: AssetModel.utilityAssetId),
            type: .subtensor
        )
    }

    private func saveSubtensorPart(
        state: Multistaking.SubtensorStakingState,
        maxApy: Multistaking.DashboardItemSubtensorPart.MaxApyUpdate = .keep,
        walletId: MetaAccountModel.Id,
        using repositoryFactory: MultistakingRepositoryFactory
    ) throws {
        let part = Multistaking.DashboardItemSubtensorPart(
            stakingOption: Multistaking.OptionWithWallet(walletId: walletId, option: subtensorOption()),
            state: state,
            maxApy: maxApy
        )

        let repository = repositoryFactory.createSubtensorRepository()
        let saveOperation = repository.saveOperation({ [part] }, { [] })

        OperationQueue().addOperations([saveOperation], waitUntilFinished: true)

        _ = try saveOperation.extractNoCancellableResultData()
    }

    private func fetchAllDashboardItems(
        walletId: MetaAccountModel.Id,
        using repositoryFactory: MultistakingRepositoryFactory
    ) throws -> [Multistaking.DashboardItem] {
        let repository = repositoryFactory.createDashboardRepository(for: walletId)
        let fetchOperation = repository.fetchAllOperation(with: RepositoryFetchOptions())

        OperationQueue().addOperations([fetchOperation], waitUntilFinished: true)

        return try fetchOperation.extractNoCancellableResultData()
    }

    private func fetchDashboardItem(
        for option: Multistaking.Option,
        walletId: MetaAccountModel.Id,
        using repositoryFactory: MultistakingRepositoryFactory
    ) throws -> Multistaking.DashboardItem {
        let allItems = try fetchAllDashboardItems(walletId: walletId, using: repositoryFactory)

        return try XCTUnwrap(allItems.first { $0.stakingOption.option == option })
    }
}

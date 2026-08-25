import XCTest
@testable import novawallet
import BigInt
import Operation_iOS

final class StakingDashboardSubtensorMapperTests: XCTestCase {
    let walletId = "subtensor-test-wallet"
    let subtensorChainId = "2f0555cc76fc2840a25a6ea3b9637146806f1f44b090c175ffde2a7e5ab36c03"
    let otherChainId = "91b171bb158e2d3848fa23a9f1c25182fb8e20313b2c1eb49219da7a70ce90c3"

    func testPartWithPositionsWritesStakeAndActiveIndependentState() throws {
        let repositoryFactory = MultistakingRepositoryFactory(storageFacade: SubstrateStorageTestFacade())

        let state = Multistaking.SubtensorStakingState(
            positions: [
                SubtensorStakingPosition(
                    hotkey: Data(repeating: 2, count: 32),
                    netuid: 0,
                    stakeAlpha: 57_816_438,
                    emissionPerTempo: 0,
                    isRegistered: true
                )
            ],
            prices: [0: 1_000_000_000]
        )

        try saveSubtensorPart(state: state, using: repositoryFactory)

        let item = try fetchDashboardItem(for: subtensorOption(), using: repositoryFactory)

        XCTAssertEqual(item.stake, BigUInt(57_816_438))
        XCTAssertEqual(item.onchainState, .activeIndependent)
        XCTAssertEqual(item.state, .active)
    }

    func testPartWithoutPositionsWritesNilStakeAndState() throws {
        let repositoryFactory = MultistakingRepositoryFactory(storageFacade: SubstrateStorageTestFacade())

        let state = Multistaking.SubtensorStakingState(positions: [], prices: [0: 1_000_000_000])

        try saveSubtensorPart(state: state, using: repositoryFactory)

        let item = try fetchDashboardItem(for: subtensorOption(), using: repositoryFactory)

        XCTAssertNil(item.stake)
        XCTAssertNil(item.onchainState)
        XCTAssertNil(item.state)
    }

    func testOffchainSaveOmittingSubtensorOptionKeepsOnchainRowWithoutApy() throws {
        let repositoryFactory = MultistakingRepositoryFactory(storageFacade: SubstrateStorageTestFacade())

        let state = Multistaking.SubtensorStakingState(
            positions: [
                SubtensorStakingPosition(
                    hotkey: Data(repeating: 2, count: 32),
                    netuid: 0,
                    stakeAlpha: 1_000_000_000,
                    emissionPerTempo: 0,
                    isRegistered: true
                )
            ],
            prices: [0: 1_000_000_000]
        )

        try saveSubtensorPart(state: state, using: repositoryFactory)

        let unrelatedOffchainPart = Multistaking.DashboardItemOffchainPart(
            stakingOption: Multistaking.OptionWithWallet(
                walletId: walletId,
                option: .init(
                    chainAssetId: ChainAssetId(chainId: otherChainId, assetId: 0),
                    type: .relaychain
                )
            ),
            maxApy: 0.17,
            hasAssignedStake: true,
            totalRewards: nil
        )

        let offchainRepository = repositoryFactory.createOffchainRepository()
        let saveOperation = offchainRepository.saveOperation({ [unrelatedOffchainPart] }, { [] })
        OperationQueue().addOperations([saveOperation], waitUntilFinished: true)
        _ = try saveOperation.extractNoCancellableResultData()

        let allItems = try fetchAllDashboardItems(using: repositoryFactory)
        let subtensorItems = allItems.filter { $0.stakingOption.option == subtensorOption() }

        XCTAssertEqual(subtensorItems.count, 1)
        XCTAssertEqual(subtensorItems.first?.stake, BigUInt(1_000_000_000))
        XCTAssertEqual(subtensorItems.first?.onchainState, .activeIndependent)
        XCTAssertNil(subtensorItems.first?.maxApy)
    }

    private func subtensorOption() -> Multistaking.Option {
        Multistaking.Option(
            chainAssetId: ChainAssetId(chainId: subtensorChainId, assetId: 0),
            type: .subtensor
        )
    }

    private func saveSubtensorPart(
        state: Multistaking.SubtensorStakingState,
        using repositoryFactory: MultistakingRepositoryFactory
    ) throws {
        let part = Multistaking.DashboardItemSubtensorPart(
            stakingOption: Multistaking.OptionWithWallet(walletId: walletId, option: subtensorOption()),
            state: state
        )

        let repository = repositoryFactory.createSubtensorRepository()
        let saveOperation = repository.saveOperation({ [part] }, { [] })

        OperationQueue().addOperations([saveOperation], waitUntilFinished: true)

        _ = try saveOperation.extractNoCancellableResultData()
    }

    private func fetchAllDashboardItems(
        using repositoryFactory: MultistakingRepositoryFactory
    ) throws -> [Multistaking.DashboardItem] {
        let repository = repositoryFactory.createDashboardRepository(for: walletId)
        let fetchOperation = repository.fetchAllOperation(with: RepositoryFetchOptions())

        OperationQueue().addOperations([fetchOperation], waitUntilFinished: true)

        return try fetchOperation.extractNoCancellableResultData()
    }

    private func fetchDashboardItem(
        for option: Multistaking.Option,
        using repositoryFactory: MultistakingRepositoryFactory
    ) throws -> Multistaking.DashboardItem {
        let allItems = try fetchAllDashboardItems(using: repositoryFactory)

        return try XCTUnwrap(allItems.first { $0.stakingOption.option == option })
    }
}

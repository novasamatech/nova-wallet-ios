import XCTest
@testable import novawallet
import Operation_iOS

final class StakingDashboardSubtensorMapperTests: XCTestCase {
    func testDashboardItemReadsBackSavedSubtensorDetails() throws {
        let operationQueue = OperationQueue()
        let repositoryFactory = MultistakingRepositoryFactory(storageFacade: SubstrateStorageTestFacade())
        let walletId = "wallet"
        let hotkey = Data(repeating: 1, count: 32)

        let part = Multistaking.DashboardItemSubtensorPart(
            stakingOption: Multistaking.OptionWithWallet(
                walletId: walletId,
                option: .init(chainAssetId: ChainAssetId(chainId: "chain", assetId: 0), type: .subtensor)
            ),
            state: Multistaking.SubtensorState(
                positions: [
                    SubtensorPosition(
                        hotkey: hotkey,
                        netuid: SubtensorPallet.rootNetuid,
                        stakeAlpha: 1_234_567_890_123_456_789,
                        isRegistered: true
                    ),
                    SubtensorPosition(hotkey: hotkey, netuid: 3, stakeAlpha: 5, isRegistered: true),
                    SubtensorPosition(hotkey: hotkey, netuid: 7, stakeAlpha: 9, isRegistered: false)
                ]
            ),
            stake: 100,
            maxApy: .keep,
            rootRate: Decimal(string: "0.123456789012345678901234567890123456"),
            subnetRate: nil,
            isFullyPriced: false
        )

        let saveOperation = repositoryFactory.createSubtensorRepository().saveOperation({ [part] }, { [] })
        operationQueue.addOperations([saveOperation], waitUntilFinished: true)
        try saveOperation.extractNoCancellableResultData()

        let fetchOperation = repositoryFactory.createDashboardRepository(for: walletId).fetchAllOperation(
            with: RepositoryFetchOptions()
        )
        operationQueue.addOperations([fetchOperation], waitUntilFinished: true)

        let items = try fetchOperation.extractNoCancellableResultData()

        XCTAssertEqual(items.map(\.subtensorDetails), [part.details])
    }
}

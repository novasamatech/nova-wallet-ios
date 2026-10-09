@testable import novawallet
import Cuckoo
import XCTest

final class SubtensorStakingSharedStateFactoryTests: XCTestCase {
    func testMissingConnectionThrowsATypedError() {
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

        let factory = StakingSharedStateFactory(
            storageFacade: SubstrateStorageTestFacade(),
            chainRegistry: MockChainRegistryProtocol().applyDefault(for: []),
            delegatedAccountSyncService: nil,
            eventCenter: EventCenter(),
            syncOperationQueue: OperationQueue(),
            repositoryOperationQueue: OperationQueue(),
            applicationConfig: ApplicationConfig.shared,
            logger: Logger.shared
        )

        let option = Multistaking.ChainAssetOption(chainAsset: ChainAsset(chain: chain, asset: asset), type: .subtensor)

        let flowState = SubtensorStakingFlowState(
            coingeckoOperationFactory: CoingeckoOperationFactory(),
            operationQueue: OperationQueue()
        )

        XCTAssertThrowsError(try factory.createSubtensorStaking(for: option, flowState: flowState)) { error in
            guard case ChainRegistryError.connectionUnavailable = error else {
                return XCTFail("Unexpected error: \(error)")
            }
        }
    }
}

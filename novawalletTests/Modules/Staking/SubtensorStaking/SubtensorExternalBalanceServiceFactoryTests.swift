import XCTest
@testable import novawallet
import Cuckoo
import Operation_iOS

final class SubtensorExternalBalanceServiceFactoryTests: XCTestCase {
    let accountId = Data(repeating: 7, count: 32)

    func testCreatesPollingSyncServiceForSubtensorStakingAsset() {
        let chainAsset = createChainAsset(stakings: [.subtensor])
        let factory = createFactory(availableChains: [chainAsset.chain])

        let services = factory.createPollingSyncServices(for: chainAsset, accountId: accountId)

        XCTAssertEqual(services.count, 1)
        XCTAssertTrue(services.first is SubtensorStakedBalanceUpdatingService)
    }

    func testNoServicesForAssetWithOtherStaking() {
        let chainAsset = createChainAsset(stakings: [.relaychain])
        let factory = createFactory(availableChains: [chainAsset.chain])

        XCTAssertTrue(factory.createPollingSyncServices(for: chainAsset, accountId: accountId).isEmpty)
    }

    func testNoServicesForAssetWithoutStakings() {
        let chainAsset = createChainAsset(stakings: nil)
        let factory = createFactory(availableChains: [chainAsset.chain])

        XCTAssertTrue(factory.createPollingSyncServices(for: chainAsset, accountId: accountId).isEmpty)
    }

    func testNoServicesWhenChainUnavailable() {
        let chainAsset = createChainAsset(stakings: [.subtensor])
        let factory = createFactory(availableChains: [])

        XCTAssertTrue(factory.createPollingSyncServices(for: chainAsset, accountId: accountId).isEmpty)
    }

    func testNoAutomaticServices() {
        let chainAsset = createChainAsset(stakings: [.subtensor])
        let factory = createFactory(availableChains: [chainAsset.chain])

        XCTAssertTrue(factory.createAutomaticSyncServices(for: chainAsset, accountId: accountId).isEmpty)
    }

    private func createChainAsset(stakings: [StakingType]?) -> ChainAsset {
        let asset = AssetModel(
            assetId: 0,
            icon: nil,
            name: "Bittensor",
            symbol: "TAO",
            precision: 9,
            priceId: nil,
            stakings: stakings,
            type: nil,
            typeExtras: nil,
            buyProviders: nil,
            sellProviders: nil,
            enabled: true,
            source: .remote
        )

        let chain = ChainModelGenerator.generateChain(assets: [asset], addressPrefix: 42)

        return ChainAsset(chain: chain, asset: asset)
    }

    private func createFactory(availableChains: [ChainModel]) -> SubtensorExternalBalanceServiceFactory {
        let chainRegistry = MockChainRegistryProtocol().applyDefault(for: Set(availableChains))

        return SubtensorExternalBalanceServiceFactory(
            storageFacade: SubstrateStorageTestFacade(),
            chainRegistry: chainRegistry,
            operationQueue: OperationQueue(),
            workingQueue: DispatchQueue.global(),
            logger: Logger.shared
        )
    }
}

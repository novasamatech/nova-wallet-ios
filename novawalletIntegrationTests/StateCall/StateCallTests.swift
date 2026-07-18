import XCTest
@testable import novawallet
import SubstrateSdk
import BigInt

final class StateCallTests: XCTestCase {
    func testFetchStakersEraReward() {
        do {
            let stakersEraReward = try fetchStakersEraReward(for: KnowChainId.polkadotAssetHub)

            Logger.shared.debug("Stakers era reward: \(stakersEraReward)")

            XCTAssertGreaterThan(stakersEraReward, 0)
        } catch {
            XCTFail("Error: \(error)")
        }
    }

    private func fetchStakersEraReward(for chainId: ChainModel.Id) throws -> BigUInt {
        let storageFacade = SubstrateStorageTestFacade()
        let chainRegistry = ChainRegistryFacade.setupForIntegrationTest(with: storageFacade)

        let runtimeProvider = try chainRegistry.getRuntimeProviderOrError(for: chainId)
        let connection = try chainRegistry.getConnectionOrError(for: chainId)

        let operationQueue = OperationQueue()

        let fetchFactory = PolkadotStakersRewardFactory(operationQueue: operationQueue)

        let wrapper = fetchFactory.createStakersRewardWrapper(
            for: connection,
            runtimeProvider: runtimeProvider
        )

        operationQueue.addOperations(wrapper.allOperations, waitUntilFinished: true)

        return try wrapper.targetOperation.extractNoCancellableResultData()
    }
}

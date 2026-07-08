import XCTest
@testable import novawallet
import Operation_iOS

class StakingDurationOperationFactoryTests: XCTestCase {
    func testWestend() {
        do {
            // given

            let chain = ChainModelGenerator.generateChain(
                generatingAssets: 2,
                addressPrefix: 42,
                assetPresicion: 12,
                hasStaking: true
            )

            let chainRegistry = MockChainRegistryProtocol().applyDefault(for: [chain])

            // Use split values (validator: 28, nominator: 2) so both durations
            // flow independently through the era-duration multiplication.
            let unstakingMock = UnstakingDurationOperationFactoryMock(
                unstakingDuration: UnstakingDuration(validator: 28, nominator: 2)
            )

            let operationFactory = BabeStakingDurationFactory(
                chainId: chain.chainId,
                chainRegistry: chainRegistry,
                unstakingDurationFactory: unstakingMock
            )

            // when

            let operationWrapper = operationFactory.createDurationOperation()

            OperationQueue().addOperations(operationWrapper.allOperations, waitUntilFinished: true)

            let duration = try operationWrapper.targetOperation.extractNoCancellableResultData()

            // then

            XCTAssertEqual(duration.era, 6 * 3600)
            XCTAssertEqual(duration.unlocking.validator, 28 * 6 * 3600)
            XCTAssertEqual(duration.unlocking.nominator, 2 * 6 * 3600)
        } catch {
            XCTFail("Unexpected error \(error)")
        }
    }
}

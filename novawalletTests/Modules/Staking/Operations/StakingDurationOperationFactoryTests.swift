import XCTest
@testable import novawallet

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

            let operationFactory = BabeStakingDurationFactory(
                chainId: chain.chainId,
                chainRegistry: chainRegistry
            )

            // when

            let operationWrapper = operationFactory.createDurationOperation()

            OperationQueue().addOperations(operationWrapper.allOperations, waitUntilFinished: true)

            let duration = try operationWrapper.targetOperation.extractNoCancellableResultData()

            XCTAssertEqual(duration.era, 6 * 3600)
            XCTAssertEqual(duration.unlocking, 2 * 6 * 3600)
        } catch {
            XCTFail("Unexpected error \(error)")
        }
    }
}

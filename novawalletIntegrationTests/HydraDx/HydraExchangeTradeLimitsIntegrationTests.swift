import XCTest
@testable import novawallet
import Operation_iOS

final class HydraExchangeTradeLimitsIntegrationTests: XCTestCase {
    func testXYKRatiosDecodeFromLiveMetadata() {
        do {
            let ratios = try performRatiosFetch(for: .xyk)

            Logger.shared.info("XYK ratios: \(ratios)")

            XCTAssertTrue(ratios.maxInRatio > 0)
            XCTAssertTrue(ratios.maxOutRatio > 0)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testOmnipoolRatiosDecodeFromLiveMetadata() {
        do {
            let ratios = try performRatiosFetch(for: .omnipool)

            Logger.shared.info("Omnipool ratios: \(ratios)")

            XCTAssertTrue(ratios.maxInRatio > 0)
            XCTAssertTrue(ratios.maxOutRatio > 0)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    private func performRatiosFetch(
        for constants: HydraExchangeTradeLimits.RatioConstants
    ) throws -> HydraExchangeTradeLimits.Ratios {
        let storageFacade = SubstrateStorageTestFacade()
        let chainRegistry = ChainRegistryFacade.setupForIntegrationTest(with: storageFacade)

        guard let runtimeService = chainRegistry.getRuntimeProvider(for: KnowChainId.hydra) else {
            throw ChainRegistryError.noChain(KnowChainId.hydra)
        }

        let operationQueue = OperationQueue()

        let coderFactoryOperation = runtimeService.fetchCoderFactoryOperation()

        let wrapper = HydraExchangeTradeLimits.createRatiosWrapper(
            for: constants,
            dependingOn: coderFactoryOperation
        ).insertingHead(operations: [coderFactoryOperation])

        return try withExtendedLifetime(chainRegistry) {
            operationQueue.addOperations(wrapper.allOperations, waitUntilFinished: true)

            return try wrapper.targetOperation.extractNoCancellableResultData()
        }
    }
}

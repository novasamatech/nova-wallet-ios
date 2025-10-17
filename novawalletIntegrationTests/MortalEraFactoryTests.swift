import XCTest
@testable import novawallet
import NovaCrypto

class MortalEraFactoryTests: XCTestCase {
    func testMortalEraPolkadot() {
        performMortalEraCalculation(chainId: KnowChainId.polkadot)
    }

    func testMortalEraKusama() {
        performMortalEraCalculation(chainId: KnowChainId.kusama)
    }

    func testMortalEraWestend() {
        performMortalEraCalculation(chainId: KnowChainId.westend)
    }

    func performMortalEraCalculation(chainId: ChainModel.Id) {
        // given
        let logger = Logger.shared

        do {
            let chainRegistry = ChainRegistryFacade.setupForIntegrationTest(
                with: SubstrateStorageTestFacade()
            )

            let connection = chainRegistry.getConnection(for: chainId)!
            let runtimeService = chainRegistry.getRuntimeProvider(for: chainId)!
            let chain = chainRegistry.getChain(for: chainId)!

            let operationFactory = MortalEraOperationFactory(chain: chain)
            let wrapper = operationFactory.createOperation(from: connection, runtimeService: runtimeService)

            let operationQueue = OperationQueue()
            operationQueue.addOperations(wrapper.allOperations, waitUntilFinished: true)

            let era = try wrapper.targetOperation.extractNoCancellableResultData()

            logger.info("Did receive era: \(era)")

        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
}

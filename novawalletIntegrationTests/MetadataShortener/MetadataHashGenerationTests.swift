import XCTest
@testable import novawallet
import Operation_iOS

final class MetadataHashGenerationTests: XCTestCase {
    func testKusamaHashGeneration() {
        do {
            if let hash = try performHashGeneration(for: KnowChainId.kusama) {
                Logger.shared.info("Kusama hash: \(hash.toHex(includePrefix: true))")
            } else {
                XCTFail("Unexpected empty kusama hash")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testPolkadotHashGeneration() {
        do {
            let hash = try performHashGeneration(for: KnowChainId.polkadot)
            XCTAssertNil(hash)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    private func performHashGeneration(for chainId: ChainModel.Id) throws -> Data? {
        let storageFacade = SubstrateStorageTestFacade()
        let chainRegistry = ChainRegistryFacade.setupForIntegrationTest(with: storageFacade)

        guard
            let chain = chainRegistry.getChain(for: chainId),
            let connection = chainRegistry.getConnection(for: chainId),
            let runtimeProvider = chainRegistry.getRuntimeProvider(for: chainId) else {
            throw ChainRegistryError.noChain(chainId)
        }

        let operationQueue = OperationQueue()

        let metadataHashFactory = MetadataHashOperationFactory(
            metadataRepositoryFactory: RuntimeMetadataRepositoryFactory(storageFacade: storageFacade),
            operationQueue: operationQueue
        )

        let hashWrapper = metadataHashFactory.createCheckMetadataHashWrapper(
            for: chain,
            connection: connection,
            runtimeProvider: runtimeProvider
        )

        operationQueue.addOperations(hashWrapper.allOperations, waitUntilFinished: true)

        return try hashWrapper.targetOperation.extractNoCancellableResultData()
    }
}

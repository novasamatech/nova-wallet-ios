import XCTest
@testable import novawallet

final class HydraXYKTests: XCTestCase {
    func testAllAvailableDirections() {
        do {
            let availableDirections = try performAvailableDirectionsFetch(
                for: KnowChainId.hydra,
                assetId: nil
            )

            Logger.shared.info("XYK Directions: \(availableDirections)")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    private func performAvailableDirectionsFetch(
        for chainId: ChainModel.Id,
        assetId: AssetModel.Id?
    ) throws -> [ChainAssetId: Set<ChainAssetId>] {
        let storageFacade = SubstrateStorageTestFacade()
        let chainRegistry = ChainRegistryFacade.setupForIntegrationTest(with: storageFacade)

        guard
            let chain = chainRegistry.getChain(for: chainId),
            let connection = chainRegistry.getConnection(for: chainId),
            let runtimeService = chainRegistry.getRuntimeProvider(for: chainId) else {
            throw ChainRegistryError.noChain(chainId)
        }

        let operationQueue = OperationQueue()

        let operationFactory = HydraXYKPoolTokensFactory(
            chain: chain,
            runtimeService: runtimeService,
            connection: connection,
            operationQueue: operationQueue
        )

        if let assetId = assetId {
            let chainAssetId = ChainAssetId(chainId: chainId, assetId: assetId)
            let wrapper = operationFactory.availableDirectionsForAsset(chainAssetId)

            operationQueue.addOperations(wrapper.allOperations, waitUntilFinished: true)

            let directions = try wrapper.targetOperation.extractNoCancellableResultData()

            return [chainAssetId: directions]
        } else {
            let wrapper = operationFactory.availableDirections()

            operationQueue.addOperations(wrapper.allOperations, waitUntilFinished: true)

            return try wrapper.targetOperation.extractNoCancellableResultData()
        }
    }
}

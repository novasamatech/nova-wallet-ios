import XCTest
@testable import novawallet

final class AssetsExchangeTests: XCTestCase {

    func testGraphBuildSucceeds() {
        let storageFacade = SubstrateStorageTestFacade()
        let chainRegistry = ChainRegistryFacade.setupForIntegrationTest(with: storageFacade)
        let operationQueue = OperationQueue()
        let logger = Logger.shared
        
        guard
            let dotPolkadot = chainRegistry.getChain(for: KnowChainId.polkadot)?.utilityChainAsset(),
            let polkadotAssetHub = chainRegistry.getChain(for: KnowChainId.statemint),
            let usdtAssetHub = polkadotAssetHub.assets.first(where: { $0.symbol == "USDT" }) else {
            XCTFail("No chain or asset")
            return
        }
        
        let assetIn = dotPolkadot.chainAssetId
        let assetOut = ChainAssetId(chainId: polkadotAssetHub.chainId, assetId: usdtAssetHub.assetId)
        
        let graphProvider = AssetsExchangeGraphProvider(
            supportedExchangeProviders: [
                CrosschainAssetsExchangeProvider(
                    syncService: XcmTransfersSyncService(
                        remoteUrl: ApplicationConfig.shared.xcmTransfersURL,
                        operationQueue: operationQueue
                    ),
                    chainRegistry: chainRegistry,
                    logger: logger
                ),
                
                AssetsHubExchangeProvider(
                    chainRegistry: chainRegistry,
                    operationQueue: operationQueue,
                    logger: logger
                ),
                
                AssetsHydraExchangeProvider(
                    chainRegistry: chainRegistry,
                    operationQueue: operationQueue,
                    logger: logger
                )
            ],
            operationQueue: operationQueue,
            logger: logger
        )

        graphProvider.setup()
     
        let expectation = XCTestExpectation()
        
        var foundPaths: [[AnyAssetExchangeEdge]]?
        
        graphProvider.subscribeGraph(
            self,
            notifyingIn: .global()
        ) { graph in
            guard
                let paths = graph?.fetchPaths(from: assetIn, to: assetOut, maxTopPaths: 4),
                !paths.isEmpty else {
                return
            }
            
            foundPaths = paths
            
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 60)
        
        let descriptions = (foundPaths ?? []).map {
            AssetsExchangeGraphDescription.getDescriptionForPath(
                edges: $0,
                chainRegistry: chainRegistry
            )
        }
        
        logger.info("Paths:")
        
        descriptions.forEach { logger.info($0) }
    }
}

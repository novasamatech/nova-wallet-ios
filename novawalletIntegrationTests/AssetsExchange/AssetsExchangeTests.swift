import XCTest
@testable import novawallet

final class AssetsExchangeTests: XCTestCase {

    func testFindPath() {
        let chainRegistry = setupChainRegistry()
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
        
        let expectation = XCTestExpectation()
        var foundPaths: [[AnyAssetExchangeEdge]]?
        
        let graphProvider = createAndSubscribeGraphProvider(for: chainRegistry) { graph in
            guard
                let paths = graph?.fetchPaths(from: assetIn, to: assetOut, maxTopPaths: 4),
                !paths.isEmpty else {
                return
            }
            
            foundPaths = paths
            
            expectation.fulfill()
        }
     
        wait(for: [expectation], timeout: 60)
        
        graphProvider.throttle()
        
        let descriptions = (foundPaths ?? []).map {
            AssetsExchangeGraphDescription.getDescriptionForPath(
                edges: $0,
                chainRegistry: chainRegistry
            )
        }
        
        logger.info("Paths:")
        
        descriptions.forEach { logger.info($0) }
    }
    
    func testFindAvailablePairs() {
        let chainRegistry = setupChainRegistry()
        
        guard
            let polkadotUtilityAsset = chainRegistry.getChain(for: KnowChainId.polkadot)?.utilityChainAssetId(),
            let hydraUtilityAsset = chainRegistry.getChain(for: KnowChainId.hydra)?.utilityChainAssetId(),
            let assetHubUtilityAsset = chainRegistry.getChain(for: KnowChainId.statemint)?.utilityChainAssetId() else {
            XCTFail("No chain or asset")
            return
        }
        
        let expectation = XCTestExpectation()
        
        let graphProvider = createAndSubscribeGraphProvider(for: chainRegistry) { graph in
            guard let reachability = graph?.fetchReachability() else {
                return
            }
            
            let hasDirections = !reachability.getAllAssetIn().isEmpty &&
                !reachability.getAllAssetOut().isEmpty &&
                !reachability.getAssetsIn(for: assetHubUtilityAsset).isEmpty &&
                !reachability.getAssetsOut(for: polkadotUtilityAsset).isEmpty &&
                !reachability.getAssetsIn(for: hydraUtilityAsset).isEmpty
            
            if hasDirections {
                expectation.fulfill()
            }
        }
        
        wait(for: [expectation], timeout: 60)
        
        graphProvider.throttle()
    }
    
    private func setupChainRegistry() -> ChainRegistryProtocol {
        let storageFacade = SubstrateStorageTestFacade()
        return ChainRegistryFacade.setupForIntegrationTest(with: storageFacade)
    }
    
    private func createAndSubscribeGraphProvider(
        for chainRegistry: ChainRegistryProtocol,
        onGraphChange: @escaping (AssetsExchangeGraphProtocol?) -> Void
    ) -> AssetsExchangeGraphProviding {
        let operationQueue = OperationQueue()
        let logger = Logger.shared
        
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
        
        graphProvider.subscribeGraph(
            self,
            notifyingIn: .global()
        ) { graph in
            onGraphChange(graph)
        }
        
        return graphProvider
    }
}

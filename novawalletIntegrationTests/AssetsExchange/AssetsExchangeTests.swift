import XCTest
@testable import novawallet

final class AssetsExchangeTests: XCTestCase {

    func testFindPath() {
        let substrateStorageFacade = SubstrateStorageTestFacade()
        let userDataStorageFacade = UserDataStorageTestFacade()
        let chainRegistry = ChainRegistryFacade.setupForIntegrationTest(with: substrateStorageFacade)
        
        let logger = Logger.shared
        let operationQueue = OperationQueue()
        
        guard
            let dotPolkadot = chainRegistry.getChain(for: KnowChainId.polkadot)?.utilityChainAsset(),
            let polkadotAssetHub = chainRegistry.getChain(for: KnowChainId.statemint),
            let usdtAssetHub = polkadotAssetHub.assets.first(where: { $0.symbol == "USDT" }) else {
            XCTFail("No chain or asset")
            return
        }
        
        let assetIn = dotPolkadot.chainAssetId
        let assetOut = ChainAssetId(chainId: polkadotAssetHub.chainId, assetId: usdtAssetHub.assetId)
        let wallet = AccountGenerator.generateMetaAccount(type: .watchOnly)
        
        let expectation = XCTestExpectation()
        var foundPaths: [[AnyAssetExchangeEdge]]?
        
        let graphProvider = createAndSubscribeGraphProvider(
            for: wallet,
            chainRegistry: chainRegistry,
            userStorageFacade: userDataStorageFacade,
            substrateStorageFacade: substrateStorageFacade
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
        
        graphProvider.throttle()
        
        guard let foundPaths else {
            XCTFail("No paths")
            return
        }
        
        let descriptions = (foundPaths).map {
            AssetsExchangeGraphDescription.getDescriptionForPath(
                edges: $0,
                chainRegistry: chainRegistry
            )
        }
        
        logger.info("Paths:")
        
        descriptions.forEach { logger.info($0) }
        
        let routeManager = AssetsExchangeRouteManager(
            possiblePaths: foundPaths,
            operationQueue: operationQueue,
            logger: logger
        )
        
        let amount = Decimal(1000).toSubstrateAmount(precision: dotPolkadot.assetDisplayInfo.assetPrecision)!
        let wrapper = routeManager.fetchRoute(for: amount, direction: .sell)
        
        operationQueue.addOperations(wrapper.allOperations, waitUntilFinished: true)
        
        do {
            guard let route = try wrapper.targetOperation.extractNoCancellableResultData() else {
                XCTFail("Route not found")
                return
            }
            
            let routeDescription = AssetsExchangeGraphDescription.getDescriptionForPath(
                edges: route.items.map({ $0.edge }),
                chainRegistry: chainRegistry
            )
            
            logger.info("Route: \(routeDescription)")
            logger.info("Quote: \(String(route.quote))")
        } catch {
            logger.error("Quote error: \(error)")
        }
    }
    
    func testFindAvailablePairs() {
        let substrateStorageFacade = SubstrateStorageTestFacade()
        let userDataStorageFacade = UserDataStorageTestFacade()
        let chainRegistry = ChainRegistryFacade.setupForIntegrationTest(with: substrateStorageFacade)
        
        let wallet = AccountGenerator.generateMetaAccount(type: .watchOnly)
        
        guard
            let polkadotUtilityAsset = chainRegistry.getChain(for: KnowChainId.polkadot)?.utilityChainAssetId(),
            let hydraUtilityAsset = chainRegistry.getChain(for: KnowChainId.hydra)?.utilityChainAssetId(),
            let assetHubUtilityAsset = chainRegistry.getChain(for: KnowChainId.statemint)?.utilityChainAssetId() else {
            XCTFail("No chain or asset")
            return
        }
        
        let expectation = XCTestExpectation()
        
        let graphProvider = createAndSubscribeGraphProvider(
            for: wallet,
            chainRegistry: chainRegistry,
            userStorageFacade: userDataStorageFacade,
            substrateStorageFacade: substrateStorageFacade
        ) { graph in
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
    
    private func createAndSubscribeGraphProvider(
        for wallet: MetaAccountModel,
        chainRegistry: ChainRegistryProtocol,
        userStorageFacade: StorageFacadeProtocol,
        substrateStorageFacade: StorageFacadeProtocol,
        onGraphChange: @escaping (AssetsExchangeGraphProtocol?) -> Void
    ) -> AssetsExchangeGraphProviding {
        let operationQueue = OperationQueue()
        let logger = Logger.shared
        
        let graphProvider = AssetsExchangeGraphProvider(
            supportedExchangeProviders: [
                CrosschainAssetsExchangeProvider(
                    wallet: wallet,
                    syncService: XcmTransfersSyncService(
                        remoteUrl: ApplicationConfig.shared.xcmTransfersURL,
                        operationQueue: operationQueue
                    ),
                    chainRegistry: chainRegistry,
                    signingWrapperFactory: SigningWrapperFactory(),
                    userStorageFacade: userStorageFacade,
                    substrateStorageFacade: substrateStorageFacade,
                    operationQueue: operationQueue,
                    logger: logger
                ),
                
                /*AssetsHubExchangeProvider(
                    chainRegistry: chainRegistry,
                    operationQueue: operationQueue,
                    logger: logger
                ),*/
                
                AssetsHydraExchangeProvider(
                    selectedWallet: wallet,
                    chainRegistry: chainRegistry,
                    userStorageFacade: userStorageFacade,
                    substrateStorageFacade: substrateStorageFacade,
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

import XCTest
@testable import novawallet
import Keystore_iOS

final class AssetsExchangeTests: XCTestCase {
    func testFindPath() {
        let params = buildCommonParams()
        
        guard
            let dotPolkadot = params.chainRegistry.getChain(for: KnowChainId.polkadot)?.utilityChainAsset(),
            let usdtAssetHubId = params.chainRegistry.getChain(
                for: KnowChainId.polkadotAssetHub
            )?.chainAssetForSymbol("USDT")?.chainAssetId else {
            XCTFail("No chain or asset")
            return
        }
        
        guard
            let amountIn = Decimal(1000).toSubstrateAmount(
                precision: dotPolkadot.assetDisplayInfo.assetPrecision
            ) else {
            XCTFail("Can't convert amount")
            return
        }
        
        do {
            let quoteArgs = AssetConversion.QuoteArgs(
                assetIn: dotPolkadot.chainAssetId,
                assetOut: usdtAssetHubId,
                amount: amountIn,
                direction: .sell
            )
            
            guard let route = try findRoute(quoteArgs: quoteArgs, params: params) else {
                XCTFail("Route not found")
                return
            }
            
            let routeDescription = AssetsExchangeGraphDescription.getDescriptionForPath(
                edges: route.items.map({ $0.edge }),
                chainRegistry: params.chainRegistry
            )
            
            params.logger.info("Route: \(routeDescription)")
            params.logger.info("Quote: \(String(route.quote))")
        } catch {
            XCTFail("Quote error: \(error)")
        }
    }
    
    func testFindAvailablePairs() {
        let params = buildCommonParams()
        
        guard
            let polkadotUtilityAsset = params.chainRegistry.getChain(for: KnowChainId.polkadot)?.utilityChainAssetId(),
            let hydraUtilityAsset = params.chainRegistry.getChain(for: KnowChainId.hydra)?.utilityChainAssetId(),
            let assetHubUtilityAsset = params.chainRegistry.getChain(
                for: KnowChainId.polkadotAssetHub
            )?.utilityChainAssetId() else {
            XCTFail("No chain or asset")
            return
        }
        
        let graph = createGraph(for: params)
        
        measure {
            guard let reachability = graph?.fetchReachability() else {
                XCTFail("No graph")
                return
            }
            
            XCTAssert(!reachability.getAllAssetIn().isEmpty)
            XCTAssert(!reachability.getAllAssetOut().isEmpty)
            XCTAssert(!reachability.getAssetsIn(for: assetHubUtilityAsset).isEmpty)
            XCTAssert(!reachability.getAssetsOut(for: polkadotUtilityAsset).isEmpty)
            XCTAssert(!reachability.getAssetsIn(for: hydraUtilityAsset).isEmpty)
        }
    }
    
    func testFindAllAssetIn() {
        let params = buildCommonParams()
        
        let graph = createGraph(for: params)
        
        measure {
            guard let assetsIn = graph?.fetchAssetsIn(given: nil) else {
                XCTFail("No graph")
                return
            }
            
            XCTAssert(!assetsIn.isEmpty)
        }
    }
    
    func testFindAssetsOutGivenIn() {
        let params = buildCommonParams()
        
        guard
            let polkadotUtilityAsset = params.chainRegistry.getChain(
                for: KnowChainId.polkadot
            )?.utilityChainAssetId() else {
            XCTFail("No chain or asset")
            return
        }
        
        let graph = createGraph(for: params)
        
        measure {
            guard let assetsIn = graph?.fetchAssetsOut(given: polkadotUtilityAsset) else {
                XCTFail("No graph")
                return
            }
            
            XCTAssert(!assetsIn.isEmpty)
        }
    }
    
    func testAssetsInGivenOut() {
        let params = buildCommonParams()
        
        guard
            let hydraUtilityAsset = params.chainRegistry.getChain(for: KnowChainId.hydra)?.utilityChainAssetId(),
            let assetHubUtilityAsset = params.chainRegistry.getChain(
                for: KnowChainId.polkadotAssetHub
            )?.utilityChainAssetId() else {
            XCTFail("No chain or asset")
            return
        }
        
        let graph = createGraph(for: params)
        
        measure {
            guard let assetInHydration = graph?.fetchAssetsIn(given: hydraUtilityAsset) else {
                XCTFail("No graph")
                return
            }
            
            guard let assetInAH = graph?.fetchAssetsIn(given: assetHubUtilityAsset) else {
                XCTFail("No graph")
                return
            }
            
            XCTAssert(!assetInAH.isEmpty)
            XCTAssert(!assetInHydration.isEmpty)
        }
    }
    
    func testNoRoute() {
        let params = buildCommonParams()
        
        guard
            let polkadotUtilityAsset = params.chainRegistry.getChain(for: KnowChainId.polkadot)?.utilityChainAssetId(),
            let kusamaUtilityAsset = params.chainRegistry.getChain(for: KnowChainId.kusama)?.utilityChainAssetId() else {
            XCTFail("No chain or asset")
            return
        }
        
        guard let graph = createGraph(for: params) else {
            XCTFail("No graph")
            return
        }
        
        measure {
            let route = graph.fetchPaths(from: kusamaUtilityAsset, to: polkadotUtilityAsset, maxTopPaths: 1)
            
            XCTAssert(route.isEmpty, "Unexpected route found")
        }
    }
    
    func testMeasureRouteSearch() {
        let params = buildCommonParams()
        
        guard
            let polkadotUtilityAsset = params.chainRegistry.getChain(for: KnowChainId.polkadot)?.utilityChainAssetId(),
            let ibtcInterlayAsset = params.chainRegistry.getChain(
                for: "bf88efe70e9e0e916416e8bed61f2b45717f517d7f3523e33c7b001e5ffcbc72"
            )?.chainAssetForSymbol("iBTC")?.chainAssetId else {
            XCTFail("No chain or asset")
            return
        }
        
        guard let graph = createGraph(for: params) else {
            XCTFail("No graph")
            return
        }
        
        measure {
            let route = graph.fetchPaths(from: polkadotUtilityAsset, to: ibtcInterlayAsset, maxTopPaths: 1)
            XCTAssert(!route.isEmpty, "No routes founds")
        }
    }
    
    func testMeasureMultiRouteSearch() {
        let params = buildCommonParams()
        
        guard
            let polkadotUtilityAsset = params.chainRegistry.getChain(for: KnowChainId.polkadot)?.utilityChainAssetId(),
            let ibtcInterlayAsset = params.chainRegistry.getChain(
                for: "bf88efe70e9e0e916416e8bed61f2b45717f517d7f3523e33c7b001e5ffcbc72"
            )?.chainAssetForSymbol("iBTC")?.chainAssetId else {
            XCTFail("No chain or asset")
            return
        }
        
        guard let graph = createGraph(for: params) else {
            XCTFail("No graph")
            return
        }
        
        measure {
            let route = graph.fetchPaths(from: polkadotUtilityAsset, to: ibtcInterlayAsset, maxTopPaths: 4)
            XCTAssert(!route.isEmpty, "No routes founds")
        }
    }
    
    func testRouteUSDTAHDOTPolkadot() throws {
        let params = buildCommonParams()
        
        let pahChain = try params.chainRegistry.getChainOrError(for: KnowChainId.polkadotAssetHub)
        let dotChain = try params.chainRegistry.getChainOrError(for: KnowChainId.polkadot)
        
        let usdtAH = try pahChain.chainAssetForSymbolOrError("USDT").chainAssetId
        let dotPolkadot = try dotChain.chainAssetForSymbolOrError("DOT").chainAssetId
        
        guard let graph = createGraph(for: params) else {
            XCTFail("No graph")
            return
        }
        
        let route = graph.fetchPaths(from: usdtAH, to: dotPolkadot, maxTopPaths: 4)
        for path in route {
            let pathDescription = AssetsExchangeGraphDescription.getDescriptionForPath(
                edges: path,
                chainRegistry: params.chainRegistry
            )
            
            Logger.shared.info("Route: \(pathDescription)")
        }
    }
    
    func testRouteUSDTAHDOTAH() throws {
        let params = buildCommonParams()
        
        let pahChain = try params.chainRegistry.getChainOrError(for: KnowChainId.polkadotAssetHub)
        
        let usdtAH = try pahChain.chainAssetForSymbolOrError("USDT").chainAssetId
        let dotAH = try pahChain.chainAssetForSymbolOrError("DOT").chainAssetId
        
        guard let graph = createGraph(for: params) else {
            XCTFail("No graph")
            return
        }
        
        let route = graph.fetchPaths(from: usdtAH, to: dotAH, maxTopPaths: 4)
        for path in route {
            let pathDescription = AssetsExchangeGraphDescription.getDescriptionForPath(
                edges: path,
                chainRegistry: params.chainRegistry
            )
            
            Logger.shared.info("Route: \(pathDescription)")
        }
    }
    
    func testRouteGDOTDOTPolkadot() throws {
        let params = buildCommonParams()
        
        let polkadot = try params.chainRegistry.getChainOrError(for: KnowChainId.polkadot)
        let hydration = try params.chainRegistry.getChainOrError(for: KnowChainId.hydra)
        
        let gdotHydraion = try hydration.chainAssetForSymbolOrError("GDOT").chainAssetId
        let dotPolkadot = try polkadot.chainAssetForSymbolOrError("DOT").chainAssetId
        
        guard let graph = createGraph(for: params) else {
            XCTFail("No graph")
            return
        }
        
        let route = graph.fetchPaths(from: gdotHydraion, to: dotPolkadot, maxTopPaths: 4)
        for path in route {
            let pathDescription = AssetsExchangeGraphDescription.getDescriptionForPath(
                edges: path,
                chainRegistry: params.chainRegistry
            )
            
            Logger.shared.info("Route: \(pathDescription)")
        }
    }
    
    func testCalculateFee() {
        let params = buildCommonParams()
        
        guard
            let dotPolkadot = params.chainRegistry.getChain(for: KnowChainId.polkadot)?.utilityChainAsset(),
            let usdtAssetHubId = params.chainRegistry.getChain(
                for: KnowChainId.polkadotAssetHub
            )?.chainAssetForSymbol("USDT")?.chainAssetId else {
            XCTFail("No chain or asset")
            return
        }
        
        guard
            let amountIn = Decimal(1000).toSubstrateAmount(
                precision: dotPolkadot.assetDisplayInfo.assetPrecision
            ) else {
            XCTFail("Can't convert amount")
            return
        }
        
        do {
            let quoteArgs = AssetConversion.QuoteArgs(
                assetIn: dotPolkadot.chainAssetId,
                assetOut: usdtAssetHubId,
                amount: amountIn,
                direction: .sell
            )
            
            guard let factory = createExchangeFactory(for: params) else {
                XCTFail("Service not found")
                return
            }
            
            let routeWrapper = factory.createQuoteWrapper(args: quoteArgs)
            
            params.operationQueue.addOperations(routeWrapper.allOperations, waitUntilFinished: true)
            
            let quote = try routeWrapper.targetOperation.extractNoCancellableResultData()

            let feeWrapper = factory.createFeeWrapper(
                for: .init(
                    route: quote.route,
                    slippage: BigRational.percent(of: 5),
                    feeAssetId: dotPolkadot.chainAssetId
                )
            )
            
            params.operationQueue.addOperations(feeWrapper.allOperations, waitUntilFinished: true)
            
            let feeResult = try feeWrapper.targetOperation.extractNoCancellableResultData()
            
            params.logger.info("Fees: \(feeResult.operationFees)")
            
        } catch {
            XCTFail("Fee error: \(error)")
        }
    }
    
    private func findRoute(
        quoteArgs: AssetConversion.QuoteArgs,
        params: AssetExchangeGraphProvidingParams
    ) throws -> AssetExchangeRoute? {
        guard let factory = createExchangeFactory(for: params) else {
            return nil
        }
        
        let routeWrapper = factory.createQuoteWrapper(args: quoteArgs)
        
        params.operationQueue.addOperations(routeWrapper.allOperations, waitUntilFinished: true)
        
        return try routeWrapper.targetOperation.extractNoCancellableResultData().route
    }
    
    private func createExchangeFactory(for params: AssetExchangeGraphProvidingParams) -> AssetsExchangeOperationFactoryProtocol? {
        guard let graph = createGraph(for: params) else {
            return nil
        }
        
        return AssetsExchangeOperationFactory(
            graph: graph,
            pathCostEstimator: MockAssetsExchangePathCostEstimator(),
            operationQueue: params.operationQueue,
            logger: params.logger
        )
    }
    
    private func createGraph(
        for params: AssetExchangeGraphProvidingParams
    ) -> AssetsExchangeGraphProtocol? {
        let exchangeStateRegistrar = AssetsExchangeStateMediator()
        
        let feeSupportProvider = AssetsExchangeFeeSupportProvider(
            feeSupportFetchersProvider: AssetExchangeFeeSupportFetchersProvider(
                chainRegistry: params.chainRegistry,
                operationQueue: params.operationQueue,
                logger: params.logger
            ),
            operationQueue: params.operationQueue,
            logger: params.logger
        )
        
        let delayedCallExecProvider = WalletDelayedExecutionProvider(
            selectedWallet: params.wallet,
            repository: WalletDelayedExecutionRepository(userStorageFacade: params.userDataStorageFacade),
            operationQueue: params.operationQueue,
            logger: params.logger
        )
        
        let pathCostEstimator = MockAssetsExchangePathCostEstimator()
        
        let graphProvider = AssetsExchangeGraphProvider(
            selectedWallet: params.wallet,
            chainRegistry: params.chainRegistry,
            supportedExchangeProviders: [
                CrosschainAssetsExchangeProvider(
                    wallet: params.wallet,
                    syncService: XcmTransfersSyncService(
                        config: ApplicationConfig.shared,
                        operationQueue: params.operationQueue
                    ),
                    chainRegistry: params.chainRegistry,
                    pathCostEstimator: pathCostEstimator,
                    fungibilityPreservationProvider: AssetFungibilityPreservationProvider.createFromKnownChains(),
                    signingWrapperFactory: SigningWrapperFactory(),
                    userStorageFacade: params.userDataStorageFacade,
                    substrateStorageFacade: params.substrateStorageFacade,
                    operationQueue: params.operationQueue,
                    logger: params.logger
                ),
                
                AssetsHubExchangeProvider(
                    wallet: params.wallet,
                    chainRegistry: params.chainRegistry,
                    pathCostEstimator: pathCostEstimator,
                    signingWrapperFactory: SigningWrapperFactory(),
                    userStorageFacade: params.userDataStorageFacade,
                    substrateStorageFacade: params.substrateStorageFacade,
                    exchangeStateRegistrar: exchangeStateRegistrar,
                    operationQueue: params.operationQueue,
                    logger: params.logger
                ),
                
                AssetsHydraExchangeProvider(
                    selectedWallet: params.wallet,
                    chainRegistry: params.chainRegistry,
                    pathCostEstimator: pathCostEstimator,
                    userStorageFacade: params.userDataStorageFacade,
                    substrateStorageFacade: params.substrateStorageFacade,
                    exchangeStateRegistrar: exchangeStateRegistrar,
                    operationQueue: params.operationQueue,
                    logger: params.logger
                )
            ],
            feeSupportProvider: feeSupportProvider,
            suffiencyProvider: AssetExchangeSufficiencyProvider(),
            delayedCallExecProvider: delayedCallExecProvider,
            operationQueue: params.operationQueue,
            logger: params.logger
        )

        graphProvider.setup()
        feeSupportProvider.setup()
        delayedCallExecProvider.setup()
        
        var actualGraph: AssetsExchangeGraphProtocol?
        
        graphProvider.subscribeGraph(
            self,
            notifyingIn: .global()
        ) { graph in
            actualGraph = graph
        }
        
        let expectation = XCTestExpectation()
        
        DispatchQueue.global().asyncAfter(deadline: .now() + .seconds(10)) {
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 60)
        
        graphProvider.throttle()
        feeSupportProvider.throttle()
        
        return actualGraph
    }
    
    private func buildCommonParams() -> AssetExchangeGraphProvidingParams {
        let substrateStorageFacade = SubstrateStorageTestFacade()
        let userDataStorageFacade = UserDataStorageTestFacade()
        let chainRegistry = ChainRegistryFacade.setupForIntegrationTest(with: substrateStorageFacade)
        
        let logger = Logger.shared
        let operationQueue = OperationQueue()
        
        let wallet = AccountGenerator.generateMetaAccount(type: .watchOnly)
        
        return .init(
            wallet: wallet,
            substrateStorageFacade: substrateStorageFacade,
            userDataStorageFacade: userDataStorageFacade,
            chainRegistry: chainRegistry,
            config: ApplicationConfig.shared,
            operationQueue: operationQueue,
            keychain: InMemoryKeychain(),
            settingsManager: InMemorySettingsManager(),
            logger: logger
        )
    }
}

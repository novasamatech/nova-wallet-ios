import XCTest
@testable import novawallet

final class AssetsExchangeTests: XCTestCase {
    struct CommonParams {
        let wallet: MetaAccountModel
        let substrateStorageFacade: StorageFacadeProtocol
        let userDataStorageFacade: StorageFacadeProtocol
        let chainRegistry: ChainRegistryProtocol
        let operationQueue: OperationQueue
        let logger: LoggerProtocol
    }
    
    func testFindPath() {
        let params = buildCommonParams()
        
        guard
            let dotPolkadot = params.chainRegistry.getChain(for: KnowChainId.polkadot)?.utilityChainAsset(),
            let usdtAssetHubId = params.chainRegistry.getChain(for: KnowChainId.statemint)?.chainAssetForSymbol("USDT")?.chainAssetId else {
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
            let assetHubUtilityAsset = params.chainRegistry.getChain(for: KnowChainId.statemint)?.utilityChainAssetId() else {
            XCTFail("No chain or asset")
            return
        }
        
        let graph = createGraph(for: params)
        
        guard let reachability = graph?.fetchReachability() else {
            XCTFail("No graph")
            return
        }
        
        let hasDirections = !reachability.getAllAssetIn().isEmpty &&
            !reachability.getAllAssetOut().isEmpty &&
            !reachability.getAssetsIn(for: assetHubUtilityAsset).isEmpty &&
            !reachability.getAssetsOut(for: polkadotUtilityAsset).isEmpty &&
            !reachability.getAssetsIn(for: hydraUtilityAsset).isEmpty
        
        XCTAssert(hasDirections, "Some directions were not found")
    }
    
    func testCalculateFee() {
        let params = buildCommonParams()
        
        guard
            let dotPolkadot = params.chainRegistry.getChain(for: KnowChainId.polkadot)?.utilityChainAsset(),
            let usdtAssetHubId = params.chainRegistry.getChain(for: KnowChainId.statemint)?.chainAssetForSymbol("USDT")?.chainAssetId else {
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
            
            guard let service = createExchangeService(for: params) else {
                XCTFail("Service not found")
                return
            }
            
            let routeWrapper = service.createQuoteWrapper(args: quoteArgs)
            
            params.operationQueue.addOperations(routeWrapper.allOperations, waitUntilFinished: true)
            
            guard let route = try routeWrapper.targetOperation.extractNoCancellableResultData() else {
                XCTFail("Route not found")
                return
            }

            let feeWrapper = service.createFeeWrapper(
                for: route,
                slippage: BigRational.percent(of: 5),
                feeAssetId: nil
            )
            
            params.operationQueue.addOperations(feeWrapper.allOperations, waitUntilFinished: true)
            
            let feeResult = try feeWrapper.targetOperation.extractNoCancellableResultData()
            
            params.logger.info("Fees: \(feeResult.fees)")
            
        } catch {
            XCTFail("Fee error: \(error)")
        }
    }
    
    private func findRoute(
        quoteArgs: AssetConversion.QuoteArgs,
        params: CommonParams
    ) throws -> AssetExchangeRoute? {
        guard let service = createExchangeService(for: params) else {
            return nil
        }
        
        let routeWrapper = service.createQuoteWrapper(args: quoteArgs)
        
        params.operationQueue.addOperations(routeWrapper.allOperations, waitUntilFinished: true)
        
        return try routeWrapper.targetOperation.extractNoCancellableResultData()
    }
    
    private func createExchangeService(for params: CommonParams) -> AssetsExchangeService? {
        guard let graph = createGraph(for: params) else {
            return nil
        }
        
        return AssetsExchangeService(
            graph: graph,
            operationQueue: params.operationQueue,
            logger: params.logger
        )
    }
    
    private func createGraph(for params: CommonParams) -> AssetsExchangeGraphProtocol? {
        let graphProvider = AssetsExchangeGraphProvider(
            supportedExchangeProviders: [
                CrosschainAssetsExchangeProvider(
                    wallet: params.wallet,
                    syncService: XcmTransfersSyncService(
                        remoteUrl: ApplicationConfig.shared.xcmTransfersURL,
                        operationQueue: params.operationQueue
                    ),
                    chainRegistry: params.chainRegistry,
                    signingWrapperFactory: SigningWrapperFactory(),
                    userStorageFacade: params.userDataStorageFacade,
                    substrateStorageFacade: params.substrateStorageFacade,
                    operationQueue: params.operationQueue,
                    logger: params.logger
                ),
                
                AssetsHubExchangeProvider(
                    wallet: params.wallet,
                    chainRegistry: params.chainRegistry,
                    signingWrapperFactory: SigningWrapperFactory(),
                    userStorageFacade: params.userDataStorageFacade,
                    substrateStorageFacade: params.substrateStorageFacade,
                    operationQueue: params.operationQueue,
                    logger: params.logger
                ),
                
                AssetsHydraExchangeProvider(
                    selectedWallet: params.wallet,
                    chainRegistry: params.chainRegistry,
                    userStorageFacade: params.userDataStorageFacade,
                    substrateStorageFacade: params.substrateStorageFacade,
                    operationQueue: params.operationQueue,
                    logger: params.logger
                )
            ],
            operationQueue: params.operationQueue,
            logger: params.logger
        )

        graphProvider.setup()
        
        var actualGraph: AssetsExchangeGraphProtocol?
        
        graphProvider.subscribeGraph(
            self,
            notifyingIn: .global()
        ) { graph in
            actualGraph = graph
        }
        
        let expectation = XCTestExpectation()
        
        DispatchQueue.global().asyncAfter(deadline: .now() + .seconds(5)) {
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 60)
        
        graphProvider.throttle()
        
        return actualGraph
    }
    
    private func buildCommonParams() -> CommonParams {
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
            operationQueue: operationQueue,
            logger: logger
        )
    }
}

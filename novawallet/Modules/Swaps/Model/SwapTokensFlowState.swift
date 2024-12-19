import Foundation
import Operation_iOS

protocol SwapTokensFlowStateProtocol {
    var assetListObservable: AssetListModelObservable { get }

    var priceStore: AssetExchangePriceStoring { get }

    var generalLocalSubscriptionFactory: GeneralStorageSubscriptionFactoryProtocol { get }

    func setupAssetExchangeService() -> AssetsExchangeServiceProtocol
}

final class SwapTokensFlowState {
    let assetListObservable: AssetListModelObservable
    let priceStore: AssetExchangePriceStoring
    let assetExchangeParams: AssetExchangeGraphProvidingParams
    let generalLocalSubscriptionFactory: GeneralStorageSubscriptionFactoryProtocol

    private var assetExchangeService: AssetsExchangeServiceProtocol?

    init(
        assetListObservable: AssetListModelObservable,
        assetExchangeParams: AssetExchangeGraphProvidingParams
    ) {
        self.assetListObservable = assetListObservable
        self.assetExchangeParams = assetExchangeParams
        priceStore = AssetExchangePriceStore(assetListObservable: assetListObservable)

        generalLocalSubscriptionFactory = GeneralStorageSubscriptionFactory(
            chainRegistry: assetExchangeParams.chainRegistry,
            storageFacade: assetExchangeParams.substrateStorageFacade,
            operationManager: OperationManager(operationQueue: assetExchangeParams.operationQueue),
            logger: assetExchangeParams.logger
        )
    }

    deinit {
        assetExchangeService?.throttle()
        assetExchangeService = nil
    }
}

extension SwapTokensFlowState: SwapTokensFlowStateProtocol {
    func setupAssetExchangeService() -> AssetsExchangeServiceProtocol {
        if let assetExchangeService {
            return assetExchangeService
        }

        let exchangesStateMediator = AssetsExchangeStateMediator()

        let feeSupportProvider = AssetsExchangeFeeSupportProvider(
            feeSupportFetchersProvider: AssetExchangeFeeSupportFetchersProvider(
                chainRegistry: assetExchangeParams.chainRegistry,
                operationQueue: assetExchangeParams.operationQueue,
                logger: assetExchangeParams.logger
            ),
            operationQueue: assetExchangeParams.operationQueue,
            logger: assetExchangeParams.logger
        )

        let pathCostEstimator = AssetsExchangePathCostEstimator(
            priceStore: priceStore,
            chainRegistry: assetExchangeParams.chainRegistry
        )

        let graphProvider = AssetExchangeFacade.createGraphProvider(
            for: assetExchangeParams,
            feeSupportProvider: feeSupportProvider,
            exchangesStateMediator: exchangesStateMediator,
            pathCostEstimator: pathCostEstimator
        )

        let service = AssetsExchangeService(
            graphProvider: graphProvider,
            feeSupportProvider: feeSupportProvider,
            exchangesStateMediator: exchangesStateMediator,
            pathCostEstimator: pathCostEstimator,
            operationQueue: assetExchangeParams.operationQueue,
            logger: Logger.shared
        )

        service.setup()

        assetExchangeService = service

        return service
    }
}

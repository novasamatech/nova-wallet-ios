import Foundation
import Operation_iOS

protocol SwapTokensFlowStateProtocol {
    var assetListObservable: AssetListModelObservable { get }

    var generalLocalSubscriptionFactory: GeneralStorageSubscriptionFactoryProtocol { get }

    func setupAssetExchangeService() -> AssetsExchangeServiceProtocol
}

final class SwapTokensFlowState {
    let assetListObservable: AssetListModelObservable
    let assetExchangeParams: AssetExchangeGraphProvidingParams
    let generalLocalSubscriptionFactory: GeneralStorageSubscriptionFactoryProtocol

    private var assetExchangeService: AssetsExchangeServiceProtocol?

    init(
        assetListObservable: AssetListModelObservable,
        assetExchangeParams: AssetExchangeGraphProvidingParams
    ) {
        self.assetListObservable = assetListObservable
        self.assetExchangeParams = assetExchangeParams

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

        let graphProvider = AssetExchangeFacade.createGraphProvider(
            for: assetExchangeParams,
            exchangesStateMediator: exchangesStateMediator
        )

        let service = AssetsExchangeService(
            graphProvider: graphProvider,
            exchangesStateMediator: exchangesStateMediator,
            operationQueue: assetExchangeParams.operationQueue,
            logger: Logger.shared
        )

        service.setup()

        assetExchangeService = service

        return service
    }
}

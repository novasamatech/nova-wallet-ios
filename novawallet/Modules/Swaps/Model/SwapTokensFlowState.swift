import Foundation
import Operation_iOS

protocol SwapTokensFlowStateProtocol {
    var assetListObservable: AssetListModelObservable { get }

    var priceStore: AssetExchangePriceStoring { get }

    var generalLocalSubscriptionFactory: GeneralStorageSubscriptionFactoryProtocol { get }

    func setupAssetExchangeService() -> AssetsExchangeServiceProtocol
    func setupWalletDelayedCallExecProvider() -> WalletDelayedExecutionProviding
}

final class SwapTokensFlowState {
    let assetListObservable: AssetListModelObservable
    let priceStore: AssetExchangePriceStoring
    let assetExchangeParams: AssetExchangeGraphProvidingParams
    let generalLocalSubscriptionFactory: GeneralStorageSubscriptionFactoryProtocol

    private var assetExchangeService: AssetsExchangeServiceProtocol?
    private var delayedCallExecProvider: WalletDelayedExecutionProviding?

    init(
        assetListObservable: AssetListModelObservable,
        assetExchangeParams: AssetExchangeGraphProvidingParams
    ) {
        self.assetListObservable = assetListObservable
        self.assetExchangeParams = assetExchangeParams
        priceStore = AssetExchangePriceStore(assetListObservable: assetListObservable)

        generalLocalSubscriptionFactory = GeneralStorageSubscriptionFactory.shared
    }

    deinit {
        assetExchangeService?.throttle()
        assetExchangeService = nil
    }
}

extension SwapTokensFlowState: SwapTokensFlowStateProtocol {
    func setupWalletDelayedCallExecProvider() -> WalletDelayedExecutionProviding {
        if let delayedCallExecProvider {
            return delayedCallExecProvider
        }

        let repository = WalletDelayedExecutionRepository(
            userStorageFacade: assetExchangeParams.userDataStorageFacade
        )

        let delayedCallExecProvider = WalletDelayedExecutionProvider(
            selectedWallet: assetExchangeParams.wallet,
            repository: repository,
            operationQueue: assetExchangeParams.operationQueue,
            logger: assetExchangeParams.logger
        )

        self.delayedCallExecProvider = delayedCallExecProvider

        delayedCallExecProvider.setup()

        return delayedCallExecProvider
    }

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

        let delayedCallExecProvider = setupWalletDelayedCallExecProvider()

        let pathCostEstimator = AssetsExchangePathCostEstimator(
            priceStore: priceStore,
            chainRegistry: assetExchangeParams.chainRegistry
        )

        let graphProvider = AssetExchangeFacade.createGraphProvider(
            for: assetExchangeParams,
            feeSupportProvider: feeSupportProvider,
            exchangesStateMediator: exchangesStateMediator,
            pathCostEstimator: pathCostEstimator,
            delayedCallExecProvider: delayedCallExecProvider
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

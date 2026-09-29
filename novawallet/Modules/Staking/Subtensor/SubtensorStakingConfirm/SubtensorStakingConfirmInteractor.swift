import UIKit
import SubstrateSdk
import Operation_iOS

final class SubtensorStakingConfirmInteractor: SubtensorStakingBaseInteractor {
    var presenter: SubtensorConfirmInteractorOutputProtocol? {
        get {
            basePresenter as? SubtensorConfirmInteractorOutputProtocol
        }

        set {
            basePresenter = newValue
        }
    }

    let catalogueService: SubtensorSubnetCatalogueServiceProtocol
    let earnConfigProvider: SubtensorEarnConfigProviderProtocol

    private let catalogueCallStore = CancellableCallStore()
    private let configCallStore = CancellableCallStore()

    init(
        baseServices: SubtensorFlowServices,
        chainAsset: ChainAsset,
        catalogueService: SubtensorSubnetCatalogueServiceProtocol,
        earnConfigProvider: SubtensorEarnConfigProviderProtocol,
        generalLocalSubscriptionFactory: GeneralStorageSubscriptionFactoryProtocol,
        logger: LoggerProtocol
    ) {
        self.catalogueService = catalogueService
        self.earnConfigProvider = earnConfigProvider

        super.init(
            chainAsset: chainAsset,
            selectedAccount: baseServices.account.chainAccount,
            positionsSyncService: baseServices.positionsSyncService,
            rootClaimableService: baseServices.rootClaimableService,
            preflightFactory: baseServices.preflightFactory,
            tradeQuoteFactory: baseServices.tradeQuoteFactory,
            operationService: baseServices.operationService,
            walletLocalSubscriptionFactory: WalletLocalSubscriptionFactory.shared,
            priceLocalSubscriptionFactory: PriceProviderFactory.shared,
            generalLocalSubscriptionFactory: generalLocalSubscriptionFactory,
            runtimeProvider: baseServices.runtimeProvider,
            currencyManager: baseServices.currencyManager,
            operationQueue: baseServices.operationQueue,
            logger: logger
        )
    }

    deinit {
        catalogueCallStore.cancel()
        configCallStore.cancel()
    }
}

extension SubtensorStakingConfirmInteractor: SubtensorConfirmInteractorInputProtocol {
    func loadSubnetData() {
        catalogueCallStore.cancel()

        executeCancellable(
            wrapper: catalogueService.createCatalogueWrapper(forcingRefresh: false),
            inOperationQueue: operationQueue,
            backingCallIn: catalogueCallStore,
            runningCallbackIn: .main
        ) { [weak self] result in
            switch result {
            case let .success(catalogue):
                self?.presenter?.didReceiveCatalogue(catalogue)
            case let .failure(error):
                self?.logger.warning("Subtensor catalogue unavailable for the confirm: \(error)")
                self?.presenter?.didReceiveCatalogue(nil)
            }
        }

        configCallStore.cancel()

        executeCancellable(
            wrapper: earnConfigProvider.createConfigWrapper(),
            inOperationQueue: operationQueue,
            backingCallIn: configCallStore,
            runningCallbackIn: .main
        ) { [weak self] result in
            switch result {
            case let .success(config):
                self?.presenter?.didReceiveEarnConfig(config)
            case let .failure(error):
                self?.logger.warning("Subtensor Earn config unavailable for the confirm mark: \(error)")
                self?.presenter?.didReceiveEarnConfig(nil)
            }
        }
    }
}

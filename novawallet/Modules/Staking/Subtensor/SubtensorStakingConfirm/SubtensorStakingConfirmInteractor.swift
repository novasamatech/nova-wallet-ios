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
    let subnetLogosProvider: SubtensorSubnetLogosProviderProtocol

    private let catalogueCallStore = CancellableCallStore()
    private let logosCallStore = CancellableCallStore()

    init(
        baseServices: SubtensorFlowServices,
        chainAsset: ChainAsset,
        catalogueService: SubtensorSubnetCatalogueServiceProtocol,
        subnetLogosProvider: SubtensorSubnetLogosProviderProtocol,
        generalLocalSubscriptionFactory: GeneralStorageSubscriptionFactoryProtocol,
        logger: LoggerProtocol
    ) {
        self.catalogueService = catalogueService
        self.subnetLogosProvider = subnetLogosProvider

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
        logosCallStore.cancel()
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

        logosCallStore.cancel()

        executeCancellable(
            wrapper: subnetLogosProvider.createLogosWrapper(),
            inOperationQueue: operationQueue,
            backingCallIn: logosCallStore,
            runningCallbackIn: .main
        ) { [weak self] result in
            switch result {
            case let .success(logos):
                self?.presenter?.didReceiveSubnetLogos(logos)
            case let .failure(error):
                self?.logger.warning("Subtensor subnet logos unavailable for the confirm mark: \(error)")
                self?.presenter?.didReceiveSubnetLogos(nil)
            }
        }
    }
}

import UIKit
import Operation_iOS

final class SubtensorClaimRewardsInteractor: SubtensorStakingBaseInteractor {
    var presenter: SubtensorClaimInteractorOutputProtocol? {
        get {
            basePresenter as? SubtensorClaimInteractorOutputProtocol
        }

        set {
            basePresenter = newValue
        }
    }

    let claimableFetchFactory: SubtensorRootClaimableFetching

    private let snapshotCallStore = CancellableCallStore()

    init(
        baseServices: SubtensorFlowServices,
        chainAsset: ChainAsset,
        claimableFetchFactory: SubtensorRootClaimableFetching,
        catalogueService: SubtensorSubnetCatalogueServiceProtocol,
        costBasisService: SubtensorCostBasisServiceProtocol,
        generalLocalSubscriptionFactory: GeneralStorageSubscriptionFactoryProtocol,
        logger: LoggerProtocol
    ) {
        self.claimableFetchFactory = claimableFetchFactory

        super.init(
            chainAsset: chainAsset,
            selectedAccount: baseServices.account.chainAccount,
            positionsSyncService: baseServices.positionsSyncService,
            rootClaimableService: baseServices.rootClaimableService,
            preflightFactory: baseServices.preflightFactory,
            tradeQuoteFactory: baseServices.tradeQuoteFactory,
            operationService: baseServices.operationService,
            catalogueService: catalogueService,
            costBasisService: costBasisService,
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
        snapshotCallStore.cancel()
    }
}

extension SubtensorClaimRewardsInteractor: SubtensorClaimInteractorInputProtocol {
    func refreshClaimSnapshot() {
        snapshotCallStore.cancel()

        executeCancellable(
            wrapper: claimableFetchFactory.createLatestClaimableWrapper(for: selectedAccount.accountId),
            inOperationQueue: operationQueue,
            backingCallIn: snapshotCallStore,
            runningCallbackIn: .main
        ) { [weak self] result in
            switch result {
            case let .success(claimable):
                self?.presenter?.didReceiveClaimSnapshot(claimable)
            case let .failure(error):
                self?.presenter?.didFailClaimSnapshot(error)
            }
        }
    }
}

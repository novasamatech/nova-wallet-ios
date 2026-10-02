import UIKit
import SubstrateSdk
import Operation_iOS

final class SubtensorUnstakeConfirmInteractor: SubtensorStakingBaseInteractor {
    var presenter: SubtensorUnstakeConfirmOutputProtocol? {
        get {
            basePresenter as? SubtensorUnstakeConfirmOutputProtocol
        }

        set {
            basePresenter = newValue
        }
    }

    let subnetLogosProvider: SubtensorSubnetLogosProviderProtocol
    let rootHoldFactory: SubtensorRootHoldFactoryProtocol

    private let catalogueCallStore = CancellableCallStore()
    private let logosCallStore = CancellableCallStore()
    private let holdsCallStore = CancellableCallStore()
    private let costBasisCallStore = CancellableCallStore()

    init(
        baseServices: SubtensorFlowServices,
        chainAsset: ChainAsset,
        catalogueService: SubtensorSubnetCatalogueServiceProtocol,
        subnetLogosProvider: SubtensorSubnetLogosProviderProtocol,
        rootHoldFactory: SubtensorRootHoldFactoryProtocol,
        costBasisService: SubtensorCostBasisServiceProtocol,
        generalLocalSubscriptionFactory: GeneralStorageSubscriptionFactoryProtocol,
        logger: LoggerProtocol
    ) {
        self.subnetLogosProvider = subnetLogosProvider
        self.rootHoldFactory = rootHoldFactory

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
        catalogueCallStore.cancel()
        logosCallStore.cancel()
        holdsCallStore.cancel()
        costBasisCallStore.cancel()
    }
}

extension SubtensorUnstakeConfirmInteractor: SubtensorUnstakeConfirmInputProtocol {
    func loadSubnetData() {
        catalogueCallStore.cancel()

        executeCancellable(
            wrapper: catalogueService.createCatalogueWrapper(),
            inOperationQueue: operationQueue,
            backingCallIn: catalogueCallStore,
            runningCallbackIn: .main
        ) { [weak self] result in
            switch result {
            case let .success(catalogue):
                self?.presenter?.didReceiveCatalogue(catalogue)
            case let .failure(error):
                self?.logger.warning("Subtensor catalogue unavailable for the unstake confirm: \(error)")
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
                self?.logger.warning("Subtensor subnet logos unavailable for the unstake confirm mark: \(error)")
                self?.presenter?.didReceiveSubnetLogos(nil)
            }
        }
    }

    func loadRootHolds(for hotkeys: [AccountId]) {
        holdsCallStore.cancel()

        executeCancellable(
            wrapper: rootHoldFactory.createHoldsWrapper(coldkey: selectedAccount.accountId, hotkeys: hotkeys),
            inOperationQueue: operationQueue,
            backingCallIn: holdsCallStore,
            runningCallbackIn: .main
        ) { [weak self] result in
            switch result {
            case let .success(holds):
                self?.presenter?.didReceiveRootHolds(holds)
            case let .failure(error):
                self?.logger.warning("Subtensor root holds unavailable for the unstake confirm: \(error)")
            }
        }
    }

    func loadCostBasis(for netuid: UInt16) {
        costBasisCallStore.cancel()

        executeCancellable(
            wrapper: costBasisService.createCostBasisWrapper(for: selectedAccount.accountId, netuid: netuid),
            inOperationQueue: operationQueue,
            backingCallIn: costBasisCallStore,
            runningCallbackIn: .main
        ) { [weak self] result in
            switch result {
            case let .success(costBasis):
                self?.presenter?.didReceiveCostBasis(costBasis)
            case let .failure(error):
                self?.logger.warning("Subtensor cost basis unavailable for the sale confirm: \(error)")
                self?.presenter?.didReceiveCostBasis(nil)
            }
        }
    }
}

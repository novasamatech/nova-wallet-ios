import Operation_iOS
import SubstrateSdk
import UIKit

final class SubtensorUnstakeSetupInteractor: SubtensorStakingBaseInteractor {
    var presenter: SubtensorUnstakeInteractorOutputProtocol? {
        get {
            basePresenter as? SubtensorUnstakeInteractorOutputProtocol
        }

        set {
            basePresenter = newValue
        }
    }

    let subnetsService: SubtensorSubnetsServiceProtocol
    let subnetLogosProvider: SubtensorSubnetLogosProviderProtocol
    let validatorFactory: SubtensorValidatorPresetFactoryProtocol
    let rootHoldFactory: SubtensorRootHoldFactoryProtocol

    private let catalogueCallStore = CancellableCallStore()
    private let logosCallStore = CancellableCallStore()
    private let validatorCallStore = CancellableCallStore()
    private let holdsCallStore = CancellableCallStore()
    private let costBasisCallStore = CancellableCallStore()

    init(
        flowServices: SubtensorFlowServices,
        chainAsset: ChainAsset,
        subnetsService: SubtensorSubnetsServiceProtocol,
        catalogueService: SubtensorSubnetCatalogueServiceProtocol,
        subnetLogosProvider: SubtensorSubnetLogosProviderProtocol,
        validatorFactory: SubtensorValidatorPresetFactoryProtocol,
        rootHoldFactory: SubtensorRootHoldFactoryProtocol,
        costBasisService: SubtensorCostBasisServiceProtocol,
        generalLocalSubscriptionFactory: GeneralStorageSubscriptionFactoryProtocol,
        logger: LoggerProtocol
    ) {
        self.subnetsService = subnetsService
        self.subnetLogosProvider = subnetLogosProvider
        self.validatorFactory = validatorFactory
        self.rootHoldFactory = rootHoldFactory

        super.init(
            chainAsset: chainAsset,
            selectedAccount: flowServices.account.chainAccount,
            positionsSyncService: flowServices.positionsSyncService,
            rootClaimableService: flowServices.rootClaimableService,
            preflightFactory: flowServices.preflightFactory,
            tradeQuoteFactory: flowServices.tradeQuoteFactory,
            operationService: flowServices.operationService,
            catalogueService: catalogueService,
            costBasisService: costBasisService,
            walletLocalSubscriptionFactory: WalletLocalSubscriptionFactory.shared,
            priceLocalSubscriptionFactory: PriceProviderFactory.shared,
            generalLocalSubscriptionFactory: generalLocalSubscriptionFactory,
            runtimeProvider: flowServices.runtimeProvider,
            currencyManager: flowServices.currencyManager,
            operationQueue: flowServices.operationQueue,
            logger: logger
        )
    }

    deinit {
        catalogueCallStore.cancel()
        logosCallStore.cancel()
        validatorCallStore.cancel()
        holdsCallStore.cancel()
        costBasisCallStore.cancel()
    }
}

extension SubtensorUnstakeSetupInteractor: SubtensorUnstakeInteractorInputProtocol {
    func loadSubnetsInfo(forcingRefresh: Bool) {
        subnetsService.fetchSubnetsInfo(
            forcingRefresh: forcingRefresh,
            runningCompletionIn: .main
        ) { [weak self] result in
            switch result {
            case let .success(info):
                self?.presenter?.didReceiveSubnetsInfo(info)
            case let .failure(error):
                self?.presenter?.didReceiveSubnetsInfoError(error)
            }
        }
    }

    func loadCatalogue() {
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
                self?.logger.warning("Subtensor catalogue unavailable for the unstake: \(error)")
                self?.presenter?.didReceiveCatalogue(nil)
            }
        }
    }

    func loadSubnetLogos() {
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
                self?.logger.warning("Subtensor subnet logos unavailable for the unstake mark: \(error)")
                self?.presenter?.didReceiveSubnetLogos(nil)
            }
        }
    }

    func loadValidator(_ hotkey: AccountId, on subnet: SubtensorSubnetRef) {
        validatorCallStore.cancel()

        executeCancellable(
            wrapper: validatorFactory.createLockedWrapper(for: hotkey, subnet: subnet),
            inOperationQueue: operationQueue,
            backingCallIn: validatorCallStore,
            runningCallbackIn: .main
        ) { [weak self] result in
            switch result {
            case let .success(validator):
                self?.presenter?.didReceiveValidator(validator, hotkey: hotkey)
            case let .failure(error):
                self?.logger.warning("Subtensor unstake validator unavailable: \(error)")
                self?.presenter?.didReceiveValidator(nil, hotkey: hotkey)
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
                self?.logger.warning("Subtensor root holds unavailable for the unstake: \(error)")
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
                self?.logger.warning("Subtensor cost basis unavailable for the sale on netuid \(netuid): \(error)")
                self?.presenter?.didReceiveCostBasis(nil)
            }
        }
    }
}

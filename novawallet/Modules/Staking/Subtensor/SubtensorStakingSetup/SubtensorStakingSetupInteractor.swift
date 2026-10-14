import Operation_iOS
import SubstrateSdk
import UIKit

final class SubtensorStakingSetupInteractor: SubtensorStakingBaseInteractor {
    var presenter: SubtensorSetupInteractorOutputProtocol? {
        get {
            basePresenter as? SubtensorSetupInteractorOutputProtocol
        }

        set {
            basePresenter = newValue
        }
    }

    let presetFactory: SubtensorValidatorPresetFactoryProtocol
    let yieldService: SubtensorYieldServiceProtocol
    let recommendationService: SubtensorRecommendationServiceProtocol
    let subnetLogosProvider: SubtensorSubnetLogosProviderProtocol
    let subnetsService: SubtensorSubnetsServiceProtocol
    let earnSettings: SubtensorEarnSettingsProtocol

    private let quickPickCallStore = CancellableCallStore()
    private let validatorCallStore = CancellableCallStore()
    private let catalogueCallStore = CancellableCallStore()
    private let yieldsCallStore = CancellableCallStore()
    private let rankingCallStore = CancellableCallStore()
    private let logosCallStore = CancellableCallStore()
    private let costBasisCallStore = CancellableCallStore()

    init(
        flowServices: SubtensorFlowServices,
        chainAsset: ChainAsset,
        presetFactory: SubtensorValidatorPresetFactoryProtocol,
        yieldService: SubtensorYieldServiceProtocol,
        catalogueService: SubtensorSubnetCatalogueServiceProtocol,
        recommendationService: SubtensorRecommendationServiceProtocol,
        subnetLogosProvider: SubtensorSubnetLogosProviderProtocol,
        subnetsService: SubtensorSubnetsServiceProtocol,
        earnSettings: SubtensorEarnSettingsProtocol,
        costBasisService: SubtensorCostBasisServiceProtocol,
        generalLocalSubscriptionFactory: GeneralStorageSubscriptionFactoryProtocol,
        logger: LoggerProtocol
    ) {
        self.presetFactory = presetFactory
        self.yieldService = yieldService
        self.recommendationService = recommendationService
        self.subnetLogosProvider = subnetLogosProvider
        self.subnetsService = subnetsService
        self.earnSettings = earnSettings

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
            walletLocalSubscriptionFactory: flowServices.walletLocalSubscriptionFactory,
            priceLocalSubscriptionFactory: flowServices.priceLocalSubscriptionFactory,
            generalLocalSubscriptionFactory: generalLocalSubscriptionFactory,
            runtimeProvider: flowServices.runtimeProvider,
            currencyManager: flowServices.currencyManager,
            operationQueue: flowServices.operationQueue,
            logger: logger
        )
    }

    deinit {
        quickPickCallStore.cancel()
        validatorCallStore.cancel()
        catalogueCallStore.cancel()
        yieldsCallStore.cancel()
        rankingCallStore.cancel()
        logosCallStore.cancel()
        costBasisCallStore.cancel()
    }
}

private extension SubtensorStakingSetupInteractor {
    func provideValidator(
        using wrapper: CompoundOperationWrapper<SubtensorValidatorDirectoryItem?>,
        subnet: SubtensorSubnetRef
    ) {
        validatorCallStore.cancel()

        executeCancellable(
            wrapper: wrapper,
            inOperationQueue: operationQueue,
            backingCallIn: validatorCallStore,
            runningCallbackIn: .main
        ) { [weak self] result in
            switch result {
            case let .success(validator):
                self?.presenter?.didReceiveValidator(validator, on: subnet)
            case let .failure(error):
                self?.logger.error("Subtensor validator preset failed: \(error)")
                self?.presenter?.didReceiveValidator(nil, on: subnet)
            }
        }
    }
}

extension SubtensorStakingSetupInteractor: SubtensorSetupInteractorInputProtocol {
    func cancelQuickPickSnapshot() { quickPickCallStore.cancel() }

    func loadQuickPickSnapshot(generation: Int, forcingRefresh: Bool) {
        quickPickCallStore.cancel()
        let subnetsService = subnetsService
        let operation = AsyncClosureOperation<SubtensorSubnetsInfo> { completion in
            subnetsService.fetchSubnetsInfo(
                forcingRefresh: forcingRefresh, runningCompletionIn: .global(), completion: completion
            )
        }
        executeCancellable(
            wrapper: CompoundOperationWrapper(targetOperation: operation),
            inOperationQueue: operationQueue,
            backingCallIn: quickPickCallStore,
            runningCallbackIn: .main
        ) { [weak self] result in
            self?.presenter?.didReceiveQuickPickSnapshot(result, generation: generation)
        }
    }

    func cachedRankingView() -> HTTPCachePeek<SubtensorRankedSubnets> {
        recommendationService.cachedRankedSubnets()
    }

    func cachedYields(netuid: UInt16) -> HTTPCachePeek<SubtensorAlphaYields> {
        yieldService.cachedAlphaYields(for: netuid)
    }

    func presetValidator(on subnet: SubtensorSubnetRef, existingHotkey: AccountId?) {
        let wrapper = presetFactory.createPresetWrapper(for: subnet, existingHotkey: existingHotkey)

        provideValidator(using: wrapper, subnet: subnet)
    }

    func loadLockedValidator(_ hotkey: AccountId, on subnet: SubtensorSubnetRef) {
        let wrapper = presetFactory.createLockedWrapper(for: hotkey, subnet: subnet)

        provideValidator(using: wrapper, subnet: subnet)
    }

    func loadSubnet(netuid: UInt16) {
        subnetsService.fetchSubnetsInfo(runningCompletionIn: .main) { [weak self] result in
            switch result {
            case let .success(info):
                guard
                    let subnet = info.subnets.first(where: { $0.netuid == netuid }),
                    let price = info.prices[netuid] else {
                    self?.presenter?.didFailSubnet(SubtensorStakingSetupError.subnetUnavailable(netuid))
                    return
                }

                self?.presenter?.didReceiveSubnet(.subnet(info: subnet, price: price))
            case let .failure(error):
                self?.presenter?.didFailSubnet(error)
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
                self?.logger.warning("Subtensor catalogue unavailable for the setup: \(error)")
                self?.presenter?.didReceiveCatalogue(nil)
            }
        }
    }

    func loadYields(netuid: UInt16) {
        yieldsCallStore.cancel()

        executeCancellable(
            wrapper: yieldService.createAlphaYieldsWrapper(for: netuid),
            inOperationQueue: operationQueue,
            backingCallIn: yieldsCallStore,
            runningCallbackIn: .main
        ) { [weak self] result in
            switch result {
            case let .success(yields):
                self?.presenter?.didReceiveYields(yields, netuid: netuid)
            case let .failure(error):
                self?.logger.warning("Subtensor subnet yields unavailable for the setup: \(error)")
                self?.presenter?.didReceiveYields(nil, netuid: netuid)
            }
        }
    }

    func loadRankingView() {
        rankingCallStore.cancel()

        executeCancellable(
            wrapper: recommendationService.createRankedSubnetsWrapper(),
            inOperationQueue: operationQueue,
            backingCallIn: rankingCallStore,
            runningCallbackIn: .main
        ) { [weak self] result in
            switch result {
            case let .success(rankingView):
                self?.presenter?.didReceiveRankingView(rankingView)
            case .failure(BittensorApiError.generationStale):
                self?.presenter?.didReceiveRankingView(self?.recommendationService.cachedRankedSubnets().value)
            case let .failure(error):
                self?.logger.warning("Subtensor ranking view unavailable for the setup: \(error)")
                self?.presenter?.didReceiveRankingView(nil)
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
                self?.logger.warning("Subtensor subnet logos unavailable for the setup mark: \(error)")
                self?.presenter?.didReceiveSubnetLogos(nil)
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
                self?.logger.warning("Subtensor cost basis unavailable for the buy on netuid \(netuid): \(error)")
                self?.presenter?.didReceiveCostBasis(nil)
            }
        }
    }

    func saveSlippage(_ tolerance: BigRational) {
        earnSettings.slippageTolerance = tolerance
    }
}

enum SubtensorStakingSetupError: Error {
    case subnetUnavailable(UInt16)
}

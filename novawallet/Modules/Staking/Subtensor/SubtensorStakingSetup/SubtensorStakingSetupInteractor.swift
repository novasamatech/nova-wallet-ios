import UIKit
import SubstrateSdk
import Operation_iOS

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
    let catalogueService: SubtensorSubnetCatalogueServiceProtocol
    let rankingViewService: SubtensorRankingViewServiceProtocol
    let earnConfigProvider: SubtensorEarnConfigProviderProtocol
    let subnetsService: SubtensorSubnetsServiceProtocol
    let earnSettings: SubtensorEarnSettingsProtocol

    private let validatorCallStore = CancellableCallStore()
    private let rootYieldCallStore = CancellableCallStore()
    private let catalogueCallStore = CancellableCallStore()
    private let yieldsCallStore = CancellableCallStore()
    private let rankingCallStore = CancellableCallStore()
    private let configCallStore = CancellableCallStore()

    init(
        flowServices: SubtensorFlowServices,
        chainAsset: ChainAsset,
        presetFactory: SubtensorValidatorPresetFactoryProtocol,
        yieldService: SubtensorYieldServiceProtocol,
        catalogueService: SubtensorSubnetCatalogueServiceProtocol,
        rankingViewService: SubtensorRankingViewServiceProtocol,
        earnConfigProvider: SubtensorEarnConfigProviderProtocol,
        subnetsService: SubtensorSubnetsServiceProtocol,
        earnSettings: SubtensorEarnSettingsProtocol,
        generalLocalSubscriptionFactory: GeneralStorageSubscriptionFactoryProtocol,
        logger: LoggerProtocol
    ) {
        self.presetFactory = presetFactory
        self.yieldService = yieldService
        self.catalogueService = catalogueService
        self.rankingViewService = rankingViewService
        self.earnConfigProvider = earnConfigProvider
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
        validatorCallStore.cancel()
        rootYieldCallStore.cancel()
        catalogueCallStore.cancel()
        yieldsCallStore.cancel()
        rankingCallStore.cancel()
        configCallStore.cancel()
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
    func presetValidator(on subnet: SubtensorSubnetRef, existingHotkey: AccountId?) {
        let wrapper = presetFactory.createPresetWrapper(for: subnet, existingHotkey: existingHotkey)

        provideValidator(using: wrapper, subnet: subnet)
    }

    func loadLockedValidator(_ hotkey: AccountId, on subnet: SubtensorSubnetRef) {
        let wrapper = presetFactory.createLockedWrapper(for: hotkey, subnet: subnet)

        provideValidator(using: wrapper, subnet: subnet)
    }

    func loadRootYield() {
        rootYieldCallStore.cancel()

        executeCancellable(
            wrapper: yieldService.createRootYieldWrapper(),
            inOperationQueue: operationQueue,
            backingCallIn: rootYieldCallStore,
            runningCallbackIn: .main
        ) { [weak self] result in
            switch result {
            case let .success(yield):
                self?.presenter?.didReceiveRootYield(yield)
            case let .failure(error):
                self?.logger.warning("Subtensor root yield unavailable: \(error)")
                self?.presenter?.didReceiveRootYield(nil)
            }
        }
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
            wrapper: catalogueService.createCatalogueWrapper(forcingRefresh: false),
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
            wrapper: rankingViewService.createRankingViewWrapper(),
            inOperationQueue: operationQueue,
            backingCallIn: rankingCallStore,
            runningCallbackIn: .main
        ) { [weak self] result in
            switch result {
            case let .success(rankingView):
                self?.presenter?.didReceiveRankingView(rankingView)
            case let .failure(error):
                self?.logger.warning("Subtensor ranking view unavailable for the setup: \(error)")
                self?.presenter?.didReceiveRankingView(nil)
            }
        }
    }

    func loadEarnConfig() {
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
                self?.logger.warning("Subtensor Earn config unavailable for the setup mark: \(error)")
                self?.presenter?.didReceiveEarnConfig(nil)
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

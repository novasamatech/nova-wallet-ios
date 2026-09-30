import Foundation
import Operation_iOS

final class SubtensorSubnetDetailsInteractor {
    weak var presenter: SubnetDetailsInteractorOutputProtocol?

    let subnet: SubtensorSubnetRef
    let chainAsset: ChainAsset
    let accountId: AccountId?
    let priceHistoryService: SubtensorPriceHistoryServiceProtocol?
    let rankingViewService: SubtensorRankingViewServiceProtocol
    let presetFactory: SubtensorValidatorPresetFactoryProtocol
    let yieldService: SubtensorYieldServiceProtocol
    let subnetLogosProvider: SubtensorSubnetLogosProviderProtocol
    let positionsSyncService: SubtensorPositionsSyncServiceProtocol?
    let walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol
    let priceLocalSubscriptionFactory: PriceProviderFactoryProtocol
    let currencyManager: CurrencyManagerProtocol
    let operationQueue: OperationQueue
    let logger: LoggerProtocol

    private var balanceProvider: StreamableProvider<AssetBalance>?
    private var priceProvider: StreamableProvider<PriceData>?
    private let historyCallStore = CancellableCallStore()
    private let listingCallStore = CancellableCallStore()
    private let rankingCallStore = CancellableCallStore()
    private let presetCallStore = CancellableCallStore()
    private let yieldsCallStore = CancellableCallStore()
    private let logosCallStore = CancellableCallStore()

    init(
        subnet: SubtensorSubnetRef,
        chainAsset: ChainAsset,
        accountId: AccountId?,
        priceHistoryService: SubtensorPriceHistoryServiceProtocol?,
        rankingViewService: SubtensorRankingViewServiceProtocol,
        presetFactory: SubtensorValidatorPresetFactoryProtocol,
        yieldService: SubtensorYieldServiceProtocol,
        subnetLogosProvider: SubtensorSubnetLogosProviderProtocol,
        positionsSyncService: SubtensorPositionsSyncServiceProtocol?,
        walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol,
        priceLocalSubscriptionFactory: PriceProviderFactoryProtocol,
        currencyManager: CurrencyManagerProtocol,
        operationQueue: OperationQueue,
        logger: LoggerProtocol
    ) {
        self.subnet = subnet
        self.chainAsset = chainAsset
        self.accountId = accountId
        self.priceHistoryService = priceHistoryService
        self.rankingViewService = rankingViewService
        self.presetFactory = presetFactory
        self.yieldService = yieldService
        self.subnetLogosProvider = subnetLogosProvider
        self.positionsSyncService = positionsSyncService
        self.walletLocalSubscriptionFactory = walletLocalSubscriptionFactory
        self.priceLocalSubscriptionFactory = priceLocalSubscriptionFactory
        self.currencyManager = currencyManager
        self.operationQueue = operationQueue
        self.logger = logger
    }

    deinit {
        historyCallStore.cancel()
        listingCallStore.cancel()
        rankingCallStore.cancel()
        presetCallStore.cancel()
        yieldsCallStore.cancel()
        logosCallStore.cancel()

        positionsSyncService?.remove(observer: self)
        positionsSyncService?.remove(failureObserver: self)
    }
}

private extension SubtensorSubnetDetailsInteractor {
    func subscribeBalance() {
        guard let accountId else {
            presenter?.didReceiveBalance(nil)
            return
        }

        balanceProvider = subscribeToAssetBalanceProvider(
            for: accountId,
            chainId: chainAsset.chain.chainId,
            assetId: chainAsset.asset.assetId
        )
    }

    func subscribePrice() {
        guard let priceId = chainAsset.asset.priceId else {
            presenter?.didReceiveTaoPrice(nil)
            return
        }

        priceProvider = subscribeToPrice(for: priceId, currency: currencyManager.selectedCurrency)
    }

    func subscribePositions() {
        guard let positionsSyncService else {
            presenter?.didReceivePositionsSyncFailed(true)
            return
        }

        positionsSyncService.add(
            observer: self,
            sendStateOnSubscription: true,
            queue: .main
        ) { [weak self] _, state in
            self?.presenter?.didReceivePositions(state)
        }

        positionsSyncService.add(
            failureObserver: self,
            sendStateOnSubscription: true,
            queue: .main
        ) { [weak self] _, isFailed in
            self?.presenter?.didReceivePositionsSyncFailed(isFailed)
        }
    }

    func loadListing() {
        guard let priceHistoryService else {
            presenter?.didReceiveListing(.notListed)
            return
        }

        let wrapper = priceHistoryService.createHistoryWrapper(
            for: subnet,
            period: .all,
            currency: currencyManager.selectedCurrency
        )

        executeCancellable(
            wrapper: wrapper,
            inOperationQueue: operationQueue,
            backingCallIn: listingCallStore,
            runningCallbackIn: .main
        ) { [weak self] result in
            switch result {
            case let .success(listing):
                self?.presenter?.didReceiveListing(listing)
            case let .failure(error):
                self?.logger.warning("Subtensor subnet listing history unavailable: \(error)")
                self?.presenter?.didReceiveListing(nil)
            }
        }
    }

    func loadRankingView() {
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
                self?.logger.warning("Subtensor ranking view unavailable for the subnet: \(error)")
                self?.presenter?.didReceiveRankingView(nil)
            }
        }
    }

    func loadYields() {
        executeCancellable(
            wrapper: yieldService.createAlphaYieldsWrapper(for: subnet.netuid),
            inOperationQueue: operationQueue,
            backingCallIn: yieldsCallStore,
            runningCallbackIn: .main
        ) { [weak self] result in
            switch result {
            case let .success(yields):
                self?.presenter?.didReceiveYields(yields)
            case let .failure(error):
                self?.logger.warning("Subtensor subnet yields unavailable: \(error)")
                self?.presenter?.didReceiveYields(nil)
            }
        }
    }

    func loadSubnetLogos() {
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
                self?.logger.warning("Subtensor subnet logos unavailable for the subnet mark: \(error)")
                self?.presenter?.didReceiveSubnetLogos(nil)
            }
        }
    }
}

extension SubtensorSubnetDetailsInteractor: SubnetDetailsInteractorInputProtocol {
    func setup() {
        subscribeBalance()
        subscribePrice()
        subscribePositions()

        loadListing()
        loadRankingView()
        loadYields()
        loadSubnetLogos()
    }

    func loadHistory(for period: SubtensorPricePeriod) {
        historyCallStore.cancel()

        guard let priceHistoryService else {
            presenter?.didReceiveHistory(.notListed, for: period)
            return
        }

        let wrapper = priceHistoryService.createHistoryWrapper(
            for: subnet,
            period: period,
            currency: currencyManager.selectedCurrency
        )

        executeCancellable(
            wrapper: wrapper,
            inOperationQueue: operationQueue,
            backingCallIn: historyCallStore,
            runningCallbackIn: .main
        ) { [weak self] result in
            switch result {
            case let .success(history):
                self?.presenter?.didReceiveHistory(history, for: period)
            case let .failure(error):
                self?.logger.warning("Subtensor subnet price history unavailable: \(error)")
                self?.presenter?.didFailHistory(for: period)
            }
        }
    }

    func presetValidator(existingHotkey: AccountId?) {
        presetCallStore.cancel()

        executeCancellable(
            wrapper: presetFactory.createPresetWrapper(for: subnet, existingHotkey: existingHotkey),
            inOperationQueue: operationQueue,
            backingCallIn: presetCallStore,
            runningCallbackIn: .main
        ) { [weak self] result in
            switch result {
            case let .success(validator):
                self?.presenter?.didReceivePreset(validator)
            case let .failure(error):
                self?.logger.warning("Subtensor subnet validator preset failed: \(error)")
                self?.presenter?.didReceivePreset(nil)
            }
        }
    }
}

extension SubtensorSubnetDetailsInteractor: WalletLocalStorageSubscriber, WalletLocalSubscriptionHandler {
    func handleAssetBalance(
        result: Result<AssetBalance?, Error>,
        accountId _: AccountId,
        chainId _: ChainModel.Id,
        assetId _: AssetModel.Id
    ) {
        switch result {
        case let .success(balance):
            presenter?.didReceiveBalance(balance)
        case let .failure(error):
            logger.error("Subtensor subnet details balance subscription failed: \(error)")
            presenter?.didReceiveBalance(nil)
        }
    }
}

extension SubtensorSubnetDetailsInteractor: PriceLocalStorageSubscriber, PriceLocalSubscriptionHandler {
    func handlePrice(result: Result<PriceData?, Error>, priceId _: AssetModel.PriceId) {
        switch result {
        case let .success(price):
            presenter?.didReceiveTaoPrice(price)
        case let .failure(error):
            logger.error("Subtensor subnet details price subscription failed: \(error)")
            presenter?.didReceiveTaoPrice(nil)
        }
    }
}

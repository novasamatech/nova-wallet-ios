import UIKit
import Operation_iOS
import Foundation_iOS

final class CrowdloanListInteractor: RuntimeConstantFetching, AnyProviderAutoCleaning {
    weak var presenter: CrowdloanListInteractorOutputProtocol?

    let eventCenter: EventCenterProtocol
    let selectedMetaAccount: MetaAccountModel
    let crowdloanState: CrowdloanSharedState
    let jsonDataProviderFactory: JsonDataProviderFactoryProtocol
    let priceLocalSubscriptionFactory: PriceProviderFactoryProtocol
    let voteServiceFactory: VoteServiceFactoryProtocol
    let walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol
    let chainRegistry: ChainRegistryProtocol
    let operationQueue: OperationQueue
    let logger: LoggerProtocol

    var generalLocalSubscriptionFactory: GeneralStorageSubscriptionFactoryProtocol {
        crowdloanState.generalLocalSubscriptionFactory
    }

    private var blockNumberSubscriptionId: UUID?
    private var blockNumberProvider: AnyDataProvider<DecodedBlockNumber>?
    private var balanceProvider: StreamableProvider<AssetBalance>?
    private var displayInfoProvider: AnySingleValueProvider<CrowdloanDisplayInfoList>?
    private var priceProvider: StreamableProvider<PriceData>?

    private var blockTimeCancellable = CancellableCallStore()

    deinit {
        clearBlockTimeService()
    }

    init(
        selectedMetaAccount: MetaAccountModel,
        crowdloanState: CrowdloanSharedState,
        chainRegistry: ChainRegistryProtocol,
        voteServiceFactory: VoteServiceFactoryProtocol,
        walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol,
        jsonDataProviderFactory: JsonDataProviderFactoryProtocol,
        priceLocalSubscriptionFactory: PriceProviderFactoryProtocol,
        eventCenter: EventCenterProtocol,
        operationQueue: OperationQueue,
        currencyManager: CurrencyManagerProtocol,
        logger: LoggerProtocol
    ) {
        self.eventCenter = eventCenter
        self.selectedMetaAccount = selectedMetaAccount
        self.crowdloanState = crowdloanState
        self.chainRegistry = chainRegistry
        self.voteServiceFactory = voteServiceFactory
        self.walletLocalSubscriptionFactory = walletLocalSubscriptionFactory
        self.jsonDataProviderFactory = jsonDataProviderFactory
        self.priceLocalSubscriptionFactory = priceLocalSubscriptionFactory
        self.operationQueue = operationQueue
        self.logger = logger

        self.currencyManager = currencyManager
    }
}

private extension CrowdloanListInteractor {
    func subscribePrice() {
        guard let chain = crowdloanState.settings.value else {
            return
        }

        if let priceId = chain.utilityAsset()?.priceId {
            priceProvider = subscribeToPrice(for: priceId, currency: selectedCurrency)
        } else {
            presenter?.didReceivePriceData(nil)
        }
    }

    func subscribeToDisplayInfo(for chain: ChainModel) {
        displayInfoProvider = nil

        guard let crowdloanUrl = chain.externalApis?.crowdloans()?.first?.url else {
            presenter?.didReceiveDisplayInfo([:])
            return
        }

        displayInfoProvider = jsonDataProviderFactory.getJson(for: crowdloanUrl)

        let updateClosure: ([DataProviderChange<CrowdloanDisplayInfoList>]) -> Void = { [weak self] changes in
            if let result = changes.reduceToLastChange() {
                self?.presenter?.didReceiveDisplayInfo(result.toMap())
            }
        }

        let failureClosure: (Error) -> Void = { [weak self] error in
            self?.presenter?.didReceiveError(error)
        }

        let options = DataProviderObserverOptions(alwaysNotifyOnRefresh: true, waitsInProgressSyncOnAdd: false)

        displayInfoProvider?.addObserver(
            self,
            deliverOn: .main,
            executing: updateClosure,
            failing: failureClosure,
            options: options
        )
    }

    func setupBlockTimeService(for chain: ChainModel) {
        do {
            let timelineChain = try chainRegistry.getTimelineChainOrError(for: chain.chainId)
            let blockTimeService = try voteServiceFactory.createBlockTimeService(for: timelineChain.chainId)

            crowdloanState.replaceBlockTimeService(blockTimeService)

            blockTimeService.setup()
        } catch {
            presenter?.didReceiveError(error)
        }
    }

    func clearBlockTimeService() {
        crowdloanState.replaceBlockTimeService(nil)
    }
}

extension CrowdloanListInteractor {
    func subscribeToAccountBalance(for accountId: AccountId, chain: ChainModel) {
        guard let chainAssetId = chain.utilityChainAssetId() else {
            return
        }

        balanceProvider = subscribeToAssetBalanceProvider(
            for: accountId,
            chainId: chainAssetId.chainId,
            assetId: chainAssetId.assetId
        )
    }

    func setup(with accountId: AccountId?, chain: ChainModel) {
        presenter?.didReceiveSelectedChain(chain)

        if let accountId {
            subscribeToAccountBalance(for: accountId, chain: chain)
        } else {
            presenter?.didReceiveAccountBalance(nil)
        }

        subscribePrice()

        setupBlockTimeService(for: chain)

        subscribeToDisplayInfo(for: chain)
    }

    func refresh(with _: ChainModel) {
        displayInfoProvider?.refresh()
    }

    func clear() {
        if let oldChain = crowdloanState.settings.value {
            putOffline(with: oldChain)
        }

        clear(singleValueProvider: &displayInfoProvider)
        clear(streamableProvider: &balanceProvider)
    }

    func handleSelectionChange(to chain: ChainModel) {
        let accountId = selectedMetaAccount.fetch(for: chain.accountRequest())?.accountId

        setup(with: accountId, chain: chain)
        becomeOnline(with: chain)
    }

    func becomeOnline(with chain: ChainModel) {
        if blockNumberProvider == nil {
            blockNumberProvider = subscribeToBlockNumber(for: chain.chainId)
        }

        provideBlockTime()
    }

    func putOffline(with _: ChainModel) {
        clear(dataProvider: &blockNumberProvider)
    }

    func setupState(onSuccess: @escaping (ChainModel?) -> Void) {
        DispatchQueue.global(qos: .userInteractive).async { [weak self] in
            self?.crowdloanState.settings.setup(runningCompletionIn: .main) { result in
                switch result {
                case let .success(chain):
                    onSuccess(chain)
                case let .failure(error):
                    self?.presenter?.didReceiveError(error)
                }
            }
        }
    }

    func provideBlockTime() {
        guard let timelineService = crowdloanState.createChainTimelineFacade() else {
            return
        }

        blockTimeCancellable.cancel()

        let blockTimeWrapper = timelineService.createBlockTimeOperation()

        executeCancellable(
            wrapper: blockTimeWrapper,
            inOperationQueue: operationQueue,
            backingCallIn: blockTimeCancellable,
            runningCallbackIn: .main
        ) { [weak self] result in
            switch result {
            case let .success(blockTime):
                self?.presenter?.didReceiveBlockDuration(blockTime)
            case let .failure(error):
                self?.presenter?.didReceiveError(error)
            }
        }
    }
}

extension CrowdloanListInteractor: SelectedCurrencyDepending {
    func applyCurrency() {
        if
            presenter != nil,
            let chain = crowdloanState.settings.value,
            let priceId = chain.utilityAsset()?.priceId {
            priceProvider = subscribeToPrice(for: priceId, currency: selectedCurrency)
        }
    }
}

import UIKit
import Operation_iOS
import Foundation_iOS

final class CrowdloanListInteractor: RuntimeConstantFetching {
    weak var presenter: CrowdloanListInteractorOutputProtocol?

    let eventCenter: EventCenterProtocol
    let selectedMetaAccount: MetaAccountModel
    let crowdloanState: CrowdloanSharedState
    let jsonDataProviderFactory: JsonDataProviderFactoryProtocol
    let priceLocalSubscriptionFactory: PriceProviderFactoryProtocol
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

    deinit {
        clearBlockTimeService()
    }

    init(
        selectedMetaAccount: MetaAccountModel,
        crowdloanState: CrowdloanSharedState,
        chainRegistry: ChainRegistryProtocol,
        jsonDataProviderFactory: JsonDataProviderFactoryProtocol,
        priceLocalSubscriptionFactory: PriceProviderFactoryProtocol,
        eventCenter: EventCenterProtocol,
        operationQueue: OperationQueue,
        logger: LoggerProtocol
    ) {
        self.eventCenter = eventCenter
        self.selectedMetaAccount = selectedMetaAccount
        self.crowdloanState = crowdloanState
        self.chainRegistry = chainRegistry
        self.jsonDataProviderFactory = jsonDataProviderFactory
        self.priceLocalSubscriptionFactory = priceLocalSubscriptionFactory
        self.operationQueue = operationQueue
        self.logger = logger
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
            presenter?.didReceivePriceData(result: nil)
        }
    }
    
    func subscribeToDisplayInfo(for chain: ChainModel) {
        displayInfoProvider = nil

        guard let crowdloanUrl = chain.externalApis?.crowdloans()?.first?.url else {
            presenter?.didReceiveDisplayInfo(result: .success([:]))
            return
        }

        displayInfoProvider = jsonDataProviderFactory.getJson(for: crowdloanUrl)

        let updateClosure: ([DataProviderChange<CrowdloanDisplayInfoList>]) -> Void = { [weak self] changes in
            if let result = changes.reduceToLastChange() {
                self?.presenter?.didReceiveDisplayInfo(result: .success(result.toMap()))
            }
        }

        let failureClosure: (Error) -> Void = { [weak self] error in
            self?.presenter?.didReceiveDisplayInfo(result: .failure(error))
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
            let blockTimeService = try serviceFactory.createBlockTimeService(for: timelineChain.chainId)

            crowdloanState.replaceBlockTimeService(blockTimeService)

            blockTimeService.setup()
        } catch {
            presenter?.didReceiveError(.blockTimeServiceFailed(error))
        }
    }
    
    func clearBlockTimeService() {
        crowdloanState.blockTimeService?.throttle()
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
        presenter?.didReceiveSelectedChain(result: .success(chain))

        if let accountId = accountId {
            subscribeToAccountBalance(for: accountId, chain: chain)
        } else {
            presenter?.didReceiveAccountBalance(result: .success(nil))
        }

        subscribePrice()

        subscribeToDisplayInfo(for: chain)
    }

    func refresh(with chain: ChainModel) {
        displayInfoProvider?.refresh()
        externalContributionsProvider?.refresh()
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
    }

    func putOffline(with chain: ChainModel) {
        clear(dataProvider: &blockNumberProvider)
    }

    func setupState(onSuccess: @escaping (ChainModel?) -> Void) {
        DispatchQueue.global(qos: .userInteractive).async { [weak self] in
            self?.crowdloanState.settings.setup(runningCompletionIn: .main) { result in
                switch result {
                case let .success(chain):
                    onSuccess(chain)
                case let .failure(error):
                    self?.presenter?.didReceiveSelectedChain(result: .failure(error))
                }
            }
        }
    }
}

extension CrowdloanListInteractor: PriceLocalStorageSubscriber, PriceLocalSubscriptionHandler {
    func handlePrice(result: Result<PriceData?, Error>, priceId _: AssetModel.PriceId) {
        presenter?.didReceivePriceData(result: result)
    }
}

extension CrowdloanListInteractor: SelectedCurrencyDepending {
    func applyCurrency() {
        if presenter != nil,
           let chain = crowdloanState.settings.value,
           let priceId = chain.utilityAsset()?.priceId {
            priceProvider = subscribeToPrice(for: priceId, currency: selectedCurrency)
        }
    }
}

extension CrowdloanListInteractor: EventVisitorProtocol {
    func processNetworkEnableChanged(event: NetworkEnabledChanged) {
        guard
            let chain = crowdloanState.settings.value,
            chain.chainId == event.chainId
        else {
            return
        }

        setupState { [weak self] chain in
            guard let chain else { return }

            self?.refresh(with: chain)
        }
    }
}

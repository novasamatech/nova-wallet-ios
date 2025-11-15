import UIKit
import Operation_iOS

final class CrowdloanYourContributionsInteractor: RuntimeConstantFetching {
    weak var presenter: CrowdloanContributionsInteractorOutputProtocol?

    let chain: ChainModel
    let crowdloanState: CrowdloanSharedState
    let selectedMetaAccount: MetaAccountModel
    let operationQueue: OperationQueue
    let priceLocalSubscriptionFactory: PriceProviderFactoryProtocol
    
    var generalLocalSubscriptionFactory: GeneralStorageSubscriptionFactoryProtocol {
        crowdloanState.generalLocalSubscriptionFactory
    }

    private var blockNumberProvider: AnyDataProvider<DecodedBlockNumber>?
    private var priceProvider: StreamableProvider<PriceData>?
    private let blockTimeCancellable = CancellableCallStore()
    
    init(
        chain: ChainModel,
        selectedMetaAccount: MetaAccountModel,
        crowdloanState: CrowdloanSharedState,
        priceLocalSubscriptionFactory: PriceProviderFactoryProtocol,
        currencyManager: CurrencyManagerProtocol,
        operationQueue: OperationQueue
    ) {
        self.chain = chain
        self.selectedMetaAccount = selectedMetaAccount
        self.crowdloanState = crowdloanState
        self.operationQueue = operationQueue
        self.priceLocalSubscriptionFactory = priceLocalSubscriptionFactory
        self.currencyManager = currencyManager
    }
}

private extension CrowdloanYourContributionsInteractor {
    func subscribeBlockNumber() {
        blockNumberProvider = subscribeToBlockNumber(for: chain.chainId)
    }

    func subscribePrice() {
        if let priceId = chain.utilityAsset()?.priceId {
            priceProvider = subscribeToPrice(for: priceId, currency: selectedCurrency)
        } else {
            presenter?.didReceivePrice(nil)
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

extension CrowdloanYourContributionsInteractor: GeneralLocalStorageSubscriber, GeneralLocalStorageHandler {
    func handleBlockNumber(
        result: Result<BlockNumber?, Error>,
        chainId: ChainModel.Id
    ) {
        switch result {
        case let .success(blockNumber):
            presenter?.didReceiveBlockNumber(blockNumber)
        case let .failure(error):
            presenter?.didReceiveError(error)
        }
    }
}

extension CrowdloanYourContributionsInteractor: CrowdloanContributionsInteractorInputProtocol {
    func setup() {
        subscribeBlockNumber()
        subscribePrice()
        provideBlockTime()
    }
}

extension CrowdloanYourContributionsInteractor: PriceLocalStorageSubscriber, PriceLocalSubscriptionHandler {
    func handlePrice(result: Result<PriceData?, Error>, priceId _: AssetModel.PriceId) {
        switch result {
        case let .success(priceData):
            presenter?.didReceivePrice(priceData)
        case let .failure(error):
            presenter?.didReceiveError(error)
        }
    }
}

extension CrowdloanYourContributionsInteractor: SelectedCurrencyDepending {
    func applyCurrency() {
        if presenter != nil, let priceId = chain.utilityAsset()?.priceId {
            priceProvider = subscribeToPrice(for: priceId, currency: selectedCurrency)
        }
    }
}

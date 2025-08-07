import Foundation
import SubstrateSdk
import Operation_iOS

class BaseSwipeGovSetupInteractor: AnyCancellableCleaning {
    weak var presenter: SwipeGovSetupInteractorOutputProtocol?

    let operationQueue: OperationQueue

    private let selectedAccount: MetaChainAccountResponse
    private let chain: ChainModel
    private let observableState: ReferendumsObservableState
    private let timelineService: ChainTimelineFacadeProtocol
    private let lockStateFactory: GovernanceLockStateFactoryProtocol
    private let connection: JSONRPCEngine
    private let runtimeProvider: RuntimeProviderProtocol

    let walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol
    let priceLocalSubscriptionFactory: PriceProviderFactoryProtocol
    let generalLocalSubscriptionFactory: GeneralStorageSubscriptionFactoryProtocol

    private var priceProvider: StreamableProvider<PriceData>?
    private var assetBalanceProvider: StreamableProvider<AssetBalance>?
    private var blockNumberProvider: AnyDataProvider<DecodedBlockNumber>?

    private let blockTimeCallStore = CancellableCallStore()
    private let lockDiffCallStore = CancellableCallStore()

    init(
        selectedAccount: MetaChainAccountResponse,
        observableState: ReferendumsObservableState,
        chain: ChainModel,
        generalLocalSubscriptionFactory: GeneralStorageSubscriptionFactoryProtocol,
        walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol,
        priceLocalSubscriptionFactory: PriceProviderFactoryProtocol,
        timelineService: ChainTimelineFacadeProtocol,
        connection: JSONRPCEngine,
        runtimeProvider: RuntimeProviderProtocol,
        currencyManager: CurrencyManagerProtocol,
        lockStateFactory: GovernanceLockStateFactoryProtocol,
        operationQueue: OperationQueue
    ) {
        self.selectedAccount = selectedAccount
        self.chain = chain
        self.observableState = observableState
        self.generalLocalSubscriptionFactory = generalLocalSubscriptionFactory
        self.timelineService = timelineService
        self.connection = connection
        self.runtimeProvider = runtimeProvider
        self.walletLocalSubscriptionFactory = walletLocalSubscriptionFactory
        self.priceLocalSubscriptionFactory = priceLocalSubscriptionFactory
        self.lockStateFactory = lockStateFactory
        self.operationQueue = operationQueue
        self.currencyManager = currencyManager
    }

    deinit {
        clearCancellable()
    }

    func process(votingPower _: VotingPowerLocal) {
        fatalError("Must be overriden by subsclass")
    }
}

// MARK: SwipeGovSetupInteractorInputProtocol

extension BaseSwipeGovSetupInteractor: SwipeGovSetupInteractorInputProtocol {
    func setup() {
        makeSubscriptions()
    }

    func remakeSubscriptions() {
        makeSubscriptions()
    }

    func refreshLockDiff(
        for trackVoting: ReferendumTracksVotingDistribution,
        newVotes: [ReferendumNewVote]
    ) {
        lockDiffCallStore.cancel()

        let wrapper = lockStateFactory.calculateLockStateDiff(
            for: trackVoting,
            newVotes: newVotes,
            from: connection,
            runtimeProvider: runtimeProvider,
            blockHash: nil
        )

        executeCancellable(
            wrapper: wrapper,
            inOperationQueue: operationQueue,
            backingCallIn: lockDiffCallStore,
            runningCallbackIn: .main
        ) { [weak self] result in
            switch result {
            case let .success(stateDiff):
                self?.presenter?.didReceiveLockStateDiff(stateDiff)
            case let .failure(error):
                self?.presenter?.didReceiveBaseError(.stateDiffFailed(error))
            }
        }
    }

    func refreshBlockTime() {
        provideBlockTime()
    }
}

// MARK: WalletLocalSubscriptionHandler

extension BaseSwipeGovSetupInteractor: WalletLocalSubscriptionHandler, WalletLocalStorageSubscriber {
    func handleAssetBalance(
        result: Result<AssetBalance?, Error>,
        accountId _: AccountId,
        chainId _: ChainModel.Id,
        assetId _: AssetModel.Id
    ) {
        switch result {
        case let .success(balance):
            presenter?.didReceiveAssetBalance(balance)
        case let .failure(error):
            presenter?.didReceiveBaseError(.assetBalanceFailed(error))
        }
    }
}

// MARK: PriceLocalSubscriptionHandler

extension BaseSwipeGovSetupInteractor: PriceLocalSubscriptionHandler, PriceLocalStorageSubscriber {
    func handlePrice(result: Result<PriceData?, Error>, priceId _: AssetModel.PriceId) {
        switch result {
        case let .success(price):
            presenter?.didReceivePrice(price)
        case let .failure(error):
            presenter?.didReceiveBaseError(.priceFailed(error))
        }
    }
}

// MARK: GeneralLocalStorageSubscriber

extension BaseSwipeGovSetupInteractor: GeneralLocalStorageSubscriber, GeneralLocalStorageHandler {
    func handleBlockNumber(result: Result<BlockNumber?, Error>, chainId _: ChainModel.Id) {
        switch result {
        case let .success(blockNumber):
            if let blockNumber = blockNumber {
                presenter?.didReceiveBlockNumber(blockNumber)
            }
        case let .failure(error):
            presenter?.didReceiveBaseError(.blockNumberSubscriptionFailed(error))
        }
    }
}

// MARK: SelectedCurrencyDepending

extension BaseSwipeGovSetupInteractor: SelectedCurrencyDepending {
    func applyCurrency() {
        guard presenter != nil else {
            return
        }

        clearAndSubscribePrice()
    }
}

// MARK: Private

extension BaseSwipeGovSetupInteractor {
    func clearCancellable() {
        blockTimeCallStore.cancel()
        lockDiffCallStore.cancel()
    }

    func provideBlockTime() {
        guard !blockTimeCallStore.hasCall else {
            return
        }

        let wrapper = timelineService.createBlockTimeOperation()

        executeCancellable(
            wrapper: wrapper,
            inOperationQueue: operationQueue,
            backingCallIn: blockTimeCallStore,
            runningCallbackIn: .main
        ) { [weak self] result in
            switch result {
            case let .success(blockTimeModel):
                self?.presenter?.didReceiveBlockTime(blockTimeModel)
            case let .failure(error):
                self?.presenter?.didReceiveBaseError(.blockTimeFailed(error))
            }
        }
    }

    func clearAndSubscribeBlockNumber() {
        blockNumberProvider?.removeObserver(self)
        blockNumberProvider = nil

        blockNumberProvider = subscribeToBlockNumber(for: timelineService.timelineChainId)
    }

    func clearAndSubscribeBalance() {
        assetBalanceProvider?.removeObserver(self)
        assetBalanceProvider = nil

        if let asset = chain.utilityAsset() {
            assetBalanceProvider = subscribeToAssetBalanceProvider(
                for: selectedAccount.chainAccount.accountId,
                chainId: chain.chainId,
                assetId: asset.assetId
            )
        }
    }

    func clearAndSubscribePrice() {
        priceProvider?.removeObserver(self)
        priceProvider = nil

        if let priceId = chain.utilityAsset()?.priceId {
            priceProvider = subscribeToPrice(for: priceId, currency: selectedCurrency)
        }
    }

    func clearAndSubscribeObservableState() {
        observableState.removeObserver(by: self)
        observableState.addObserver(
            with: self,
            sendStateOnSubscription: true,
            queue: .main
        ) { [weak self] _, new in
            guard let accountVotes = new.value.voting else {
                return
            }
            self?.presenter?.didReceiveAccountVotes(accountVotes)
        }
    }

    func makeSubscriptions() {
        clearAndSubscribeBalance()
        clearAndSubscribePrice()
        clearAndSubscribeBlockNumber()
        clearAndSubscribeObservableState()
    }
}

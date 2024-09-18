import Foundation
import SubstrateSdk
import Operation_iOS

class BaseSwipeGovSetupInteractor: AnyCancellableCleaning {
    weak var presenter: SwipeGovSetupInteractorOutputProtocol?

    let operationQueue: OperationQueue

    private let selectedAccount: MetaChainAccountResponse
    private let chain: ChainModel
    private let observableState: ReferendumsObservableState
    private let blockTimeService: BlockTimeEstimationServiceProtocol
    private let blockTimeFactory: BlockTimeOperationFactoryProtocol
    private let lockStateFactory: GovernanceLockStateFactoryProtocol
    private let connection: JSONRPCEngine
    private let runtimeProvider: RuntimeProviderProtocol

    let walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol
    let priceLocalSubscriptionFactory: PriceProviderFactoryProtocol
    let generalLocalSubscriptionFactory: GeneralStorageSubscriptionFactoryProtocol

    private var priceProvider: StreamableProvider<PriceData>?
    private var assetBalanceProvider: StreamableProvider<AssetBalance>?
    private var blockNumberProvider: AnyDataProvider<DecodedBlockNumber>?

    private var blockTimeCancellable: CancellableCall?
    private var lockDiffCancellable: CancellableCall?

    init(
        selectedAccount: MetaChainAccountResponse,
        observableState: ReferendumsObservableState,
        chain: ChainModel,
        generalLocalSubscriptionFactory: GeneralStorageSubscriptionFactoryProtocol,
        walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol,
        priceLocalSubscriptionFactory: PriceProviderFactoryProtocol,
        blockTimeService: BlockTimeEstimationServiceProtocol,
        blockTimeFactory: BlockTimeOperationFactoryProtocol,
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
        self.blockTimeService = blockTimeService
        self.blockTimeFactory = blockTimeFactory
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
        newVotes: [ReferendumNewVote],
        blockHash: Data?
    ) {
        clear(cancellable: &lockDiffCancellable)

        let wrapper = lockStateFactory.calculateLockStateDiff(
            for: trackVoting,
            newVotes: newVotes,
            from: connection,
            runtimeProvider: runtimeProvider,
            blockHash: blockHash
        )

        wrapper.targetOperation.completionBlock = { [weak self] in
            DispatchQueue.main.async {
                guard wrapper === self?.lockDiffCancellable else {
                    return
                }

                self?.lockDiffCancellable = nil

                do {
                    let stateDiff = try wrapper.targetOperation.extractNoCancellableResultData()
                    self?.presenter?.didReceiveLockStateDiff(stateDiff)
                } catch {
                    self?.presenter?.didReceiveBaseError(.stateDiffFailed(error))
                }
            }
        }

        lockDiffCancellable = wrapper

        operationQueue.addOperations(wrapper.allOperations, waitUntilFinished: false)
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
        clear(cancellable: &blockTimeCancellable)
        clear(cancellable: &lockDiffCancellable)
    }

    func provideBlockTime() {
        guard blockTimeCancellable == nil else {
            return
        }

        let wrapper = blockTimeFactory.createBlockTimeOperation(
            from: runtimeProvider,
            blockTimeEstimationService: blockTimeService
        )

        wrapper.targetOperation.completionBlock = { [weak self] in
            DispatchQueue.main.async {
                guard wrapper === self?.blockTimeCancellable else {
                    return
                }

                self?.blockTimeCancellable = nil

                do {
                    let blockTimeModel = try wrapper.targetOperation.extractNoCancellableResultData()
                    self?.presenter?.didReceiveBlockTime(blockTimeModel)
                } catch {
                    self?.presenter?.didReceiveBaseError(.blockTimeFailed(error))
                }
            }
        }

        blockTimeCancellable = wrapper

        operationQueue.addOperations(wrapper.allOperations, waitUntilFinished: false)
    }

    func clearAndSubscribeBlockNumber() {
        blockNumberProvider?.removeObserver(self)
        blockNumberProvider = nil

        blockNumberProvider = subscribeToBlockNumber(for: chain.chainId)
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

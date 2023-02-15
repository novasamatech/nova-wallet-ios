import Foundation
import SubstrateSdk
import RobinHood
import BigInt

class GovernanceDelegateInteractor: AnyCancellableCleaning {
    weak var basePresenter: GovernanceDelegateInteractorOutputProtocol?

    let selectedAccount: MetaChainAccountResponse
    let chain: ChainModel
    let referendumsSubscriptionFactory: GovernanceSubscriptionFactoryProtocol
    let walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol
    let priceLocalSubscriptionFactory: PriceProviderFactoryProtocol
    let extrinsicService: ExtrinsicServiceProtocol
    let feeProxy: ExtrinsicFeeProxyProtocol
    let extrinsicFactory: GovernanceExtrinsicFactoryProtocol
    let generalLocalSubscriptionFactory: GeneralStorageSubscriptionFactoryProtocol
    let blockTimeService: BlockTimeEstimationServiceProtocol
    let blockTimeFactory: BlockTimeOperationFactoryProtocol
    let lockStateFactory: GovernanceLockStateFactoryProtocol
    let connection: JSONRPCEngine
    let runtimeProvider: RuntimeProviderProtocol
    let operationQueue: OperationQueue

    private var priceProvider: AnySingleValueProvider<PriceData>?
    private var assetBalanceProvider: StreamableProvider<AssetBalance>?
    private var blockNumberProvider: AnyDataProvider<DecodedBlockNumber>?

    private var blockTimeCancellable: CancellableCall?
    private var lockDiffCancellable: CancellableCall?

    init(
        selectedAccount: MetaChainAccountResponse,
        chain: ChainModel,
        generalLocalSubscriptionFactory: GeneralStorageSubscriptionFactoryProtocol,
        referendumsSubscriptionFactory: GovernanceSubscriptionFactoryProtocol,
        walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol,
        priceLocalSubscriptionFactory: PriceProviderFactoryProtocol,
        blockTimeService: BlockTimeEstimationServiceProtocol,
        blockTimeFactory: BlockTimeOperationFactoryProtocol,
        connection: JSONRPCEngine,
        runtimeProvider: RuntimeProviderProtocol,
        currencyManager: CurrencyManagerProtocol,
        extrinsicFactory: GovernanceExtrinsicFactoryProtocol,
        extrinsicService: ExtrinsicServiceProtocol,
        feeProxy: ExtrinsicFeeProxyProtocol,
        lockStateFactory: GovernanceLockStateFactoryProtocol,
        operationQueue: OperationQueue
    ) {
        self.selectedAccount = selectedAccount
        self.chain = chain
        self.generalLocalSubscriptionFactory = generalLocalSubscriptionFactory
        self.blockTimeService = blockTimeService
        self.blockTimeFactory = blockTimeFactory
        self.connection = connection
        self.runtimeProvider = runtimeProvider
        self.referendumsSubscriptionFactory = referendumsSubscriptionFactory
        self.walletLocalSubscriptionFactory = walletLocalSubscriptionFactory
        self.priceLocalSubscriptionFactory = priceLocalSubscriptionFactory
        self.extrinsicFactory = extrinsicFactory
        self.extrinsicService = extrinsicService
        self.feeProxy = feeProxy
        self.lockStateFactory = lockStateFactory
        self.operationQueue = operationQueue
        self.currencyManager = currencyManager
    }

    deinit {
        clearVotesSubscription()
        clearCancellable()
    }

    private func clearCancellable() {
        clear(cancellable: &blockTimeCancellable)
        clear(cancellable: &lockDiffCancellable)
    }

    private func clearVotesSubscription() {
        referendumsSubscriptionFactory.unsubscribeFromAccountVotes(
            self,
            accountId: selectedAccount.chainAccount.accountId
        )
    }

    private func provideBlockTime() {
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
                    self?.basePresenter?.didReceiveBlockTime(blockTimeModel)
                } catch {
                    self?.basePresenter?.didReceiveBaseError(.blockTimeFailed(error))
                }
            }
        }

        blockTimeCancellable = wrapper

        operationQueue.addOperations(wrapper.allOperations, waitUntilFinished: false)
    }

    private func subscribeAccountVotes() {
        referendumsSubscriptionFactory.subscribeToAccountVotes(
            self,
            accountId: selectedAccount.chainAccount.accountId
        ) { [weak self] result in
            switch result {
            case let .success(storageResult):
                self?.basePresenter?.didReceiveAccountVotes(storageResult)
            case let .failure(error):
                self?.basePresenter?.didReceiveBaseError(.accountVotesFailed(error))
            case .none:
                self?.basePresenter?.didReceiveAccountVotes(.init(value: nil, blockHash: nil))
            }
        }
    }

    private func clearAndSubscribeBlockNumber() {
        blockNumberProvider?.removeObserver(self)
        blockNumberProvider = nil

        blockNumberProvider = subscribeToBlockNumber(for: chain.chainId)
    }

    private func clearAndSubscribeBalance() {
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

    private func clearAndSubscribePrice() {
        priceProvider?.removeObserver(self)
        priceProvider = nil

        if let priceId = chain.utilityAsset()?.priceId {
            priceProvider = subscribeToPrice(for: priceId, currency: selectedCurrency)
        }
    }

    private func makeSubscriptions() {
        clearAndSubscribeBalance()
        clearAndSubscribePrice()
        clearAndSubscribeBlockNumber()

        clearVotesSubscription()
        subscribeAccountVotes()
    }

    func createExtrinsicBuilderClosure(
        for actions: [GovernanceDelegatorAction]
    ) -> ExtrinsicBuilderClosure {
        { [weak self] builder in
            guard let strongSelf = self else {
                return builder
            }

            return try strongSelf.extrinsicFactory.delegationUpdate(
                with: actions,
                builder: builder
            )
        }
    }

    func setup() {
        feeProxy.delegate = self

        makeSubscriptions()
    }

    func remakeSubscriptions() {
        makeSubscriptions()
    }

    func handleAccountLocks(
        result _: Result<[DataProviderChange<AssetLock>], Error>,
        accountId _: AccountId,
        chainId _: ChainModel.Id,
        assetId _: AssetModel.Id
    ) {}
}

extension GovernanceDelegateInteractor {
    func estimateFee(for actions: [GovernanceDelegatorAction]) {
        let reuseIdentifier = "\(actions.hashValue)"

        let closure = createExtrinsicBuilderClosure(for: actions)

        feeProxy.estimateFee(
            using: extrinsicService,
            reuseIdentifier: reuseIdentifier,
            setupBy: closure
        )
    }

    func refreshDelegateStateDiff(
        for trackVoting: ReferendumTracksVotingDistribution,
        newDelegation: GovernanceNewDelegation
    ) {
        clear(cancellable: &lockDiffCancellable)

        let wrapper = lockStateFactory.calculateDelegateStateDiff(
            for: trackVoting,
            newDelegation: newDelegation,
            connection: connection,
            runtimeProvider: runtimeProvider
        )

        wrapper.targetOperation.completionBlock = { [weak self] in
            DispatchQueue.main.async {
                guard wrapper === self?.lockDiffCancellable else {
                    return
                }

                self?.lockDiffCancellable = nil

                do {
                    let stateDiff = try wrapper.targetOperation.extractNoCancellableResultData()
                    self?.basePresenter?.didReceiveDelegateStateDiff(stateDiff)
                } catch {
                    self?.basePresenter?.didReceiveBaseError(.stateDiffFailed(error))
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

extension GovernanceDelegateInteractor: WalletLocalSubscriptionHandler, WalletLocalStorageSubscriber {
    func handleAssetBalance(
        result: Result<AssetBalance?, Error>,
        accountId _: AccountId,
        chainId _: ChainModel.Id,
        assetId _: AssetModel.Id
    ) {
        switch result {
        case let .success(balance):
            basePresenter?.didReceiveAssetBalance(balance)
        case let .failure(error):
            basePresenter?.didReceiveBaseError(.assetBalanceFailed(error))
        }
    }
}

extension GovernanceDelegateInteractor: PriceLocalSubscriptionHandler, PriceLocalStorageSubscriber {
    func handlePrice(result: Result<PriceData?, Error>, priceId _: AssetModel.PriceId) {
        switch result {
        case let .success(price):
            basePresenter?.didReceivePrice(price)
        case let .failure(error):
            basePresenter?.didReceiveBaseError(.priceFailed(error))
        }
    }
}

extension GovernanceDelegateInteractor: ExtrinsicFeeProxyDelegate {
    func didReceiveFee(result: Result<RuntimeDispatchInfo, Error>, for _: TransactionFeeId) {
        switch result {
        case let .success(dispatchInfo):
            if let fee = BigUInt(dispatchInfo.fee) {
                basePresenter?.didReceiveFee(fee)
            }
        case let .failure(error):
            basePresenter?.didReceiveBaseError(.feeFailed(error))
        }
    }
}

extension GovernanceDelegateInteractor: GeneralLocalStorageSubscriber, GeneralLocalStorageHandler {
    func handleBlockNumber(result: Result<BlockNumber?, Error>, chainId _: ChainModel.Id) {
        switch result {
        case let .success(blockNumber):
            if blockNumber != nil {
                provideBlockTime()
            }
        case let .failure(error):
            basePresenter?.didReceiveBaseError(.blockNumberSubscriptionFailed(error))
        }
    }
}

extension GovernanceDelegateInteractor: SelectedCurrencyDepending {
    func applyCurrency() {
        guard basePresenter != nil else {
            return
        }

        clearAndSubscribePrice()
    }
}

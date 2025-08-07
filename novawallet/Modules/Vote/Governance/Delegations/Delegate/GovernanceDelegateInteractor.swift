import Foundation
import SubstrateSdk
import Operation_iOS
import BigInt

class GovernanceDelegateInteractor: AnyCancellableCleaning {
    weak var basePresenter: GovernanceDelegateInteractorOutputProtocol?

    let selectedAccount: MetaChainAccountResponse
    let chain: ChainModel
    let referendumsSubscriptionFactory: GovernanceSubscriptionFactoryProtocol
    let walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol
    let priceLocalSubscriptionFactory: PriceProviderFactoryProtocol
    let extrinsicService: ExtrinsicServiceProtocol
    let feeProxy: MultiExtrinsicFeeProxyProtocol
    let extrinsicFactory: GovernanceExtrinsicFactoryProtocol
    let generalLocalSubscriptionFactory: GeneralStorageSubscriptionFactoryProtocol
    let timelineService: ChainTimelineFacadeProtocol
    let lockStateFactory: GovernanceLockStateFactoryProtocol
    let chainRegistry: ChainRegistryProtocol
    let operationQueue: OperationQueue

    private var priceProvider: StreamableProvider<PriceData>?
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
        timelineService: ChainTimelineFacadeProtocol,
        chainRegistry: ChainRegistryProtocol,
        currencyManager: CurrencyManagerProtocol,
        extrinsicFactory: GovernanceExtrinsicFactoryProtocol,
        extrinsicService: ExtrinsicServiceProtocol,
        feeProxy: MultiExtrinsicFeeProxyProtocol,
        lockStateFactory: GovernanceLockStateFactoryProtocol,
        operationQueue: OperationQueue
    ) {
        self.selectedAccount = selectedAccount
        self.chain = chain
        self.generalLocalSubscriptionFactory = generalLocalSubscriptionFactory
        self.timelineService = timelineService
        self.chainRegistry = chainRegistry
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

        let wrapper = timelineService.createBlockTimeOperation()

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

        blockNumberProvider = subscribeToBlockNumber(for: timelineService.timelineChainId)
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

    func createExtrinsicSplitter(for actions: [GovernanceDelegatorAction]) throws -> ExtrinsicSplitting {
        let splitter = ExtrinsicSplitter(
            chain: chain,
            maxCallsPerExtrinsic: selectedAccount.chainAccount.type.maxCallsPerExtrinsic,
            chainRegistry: chainRegistry,
            operationQueue: operationQueue
        )

        return try extrinsicFactory.delegationUpdate(with: actions, splitter: splitter)
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
        do {
            let reuseIdentifier = "\(actions.hashValue)"

            let splitter = try createExtrinsicSplitter(for: actions)

            feeProxy.estimateFee(
                from: splitter,
                service: extrinsicService,
                reuseIdentifier: reuseIdentifier,
                payingIn: chain.utilityChainAssetId()
            )
        } catch {
            basePresenter?.didReceiveBaseError(.feeFailed(error))
        }
    }

    func refreshDelegateStateDiff(
        for trackVoting: ReferendumTracksVotingDistribution,
        newDelegation: GovernanceNewDelegation
    ) {
        clear(cancellable: &lockDiffCancellable)

        guard let runtimeProvider = chainRegistry.getRuntimeProvider(for: chain.chainId) else {
            basePresenter?.didReceiveBaseError(.stateDiffFailed(ChainRegistryError.runtimeMetadaUnavailable))
            return
        }

        let wrapper = lockStateFactory.calculateDelegateStateDiff(
            for: trackVoting,
            newDelegation: newDelegation,
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

extension GovernanceDelegateInteractor: MultiExtrinsicFeeProxyDelegate {
    func didReceiveTotalFee(result: Result<ExtrinsicFeeProtocol, Error>, for _: TransactionFeeId) {
        switch result {
        case let .success(fee):
            basePresenter?.didReceiveFee(fee)
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

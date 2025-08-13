import Foundation
import Operation_iOS
import BigInt
import SubstrateSdk

class ReferendumVoteInteractor: AnyCancellableCleaning {
    weak var basePresenter: ReferendumVoteInteractorOutputProtocol?

    let selectedAccount: MetaChainAccountResponse
    let chain: ChainModel
    let walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol
    let priceLocalSubscriptionFactory: PriceProviderFactoryProtocol
    let extrinsicService: ExtrinsicServiceProtocol
    let feeProxy: MultiExtrinsicFeeProxyProtocol
    let extrinsicFactory: GovernanceExtrinsicFactoryProtocol
    let generalLocalSubscriptionFactory: GeneralStorageSubscriptionFactoryProtocol
    let blockTimeService: BlockTimeEstimationServiceProtocol
    let blockTimeFactory: BlockTimeOperationFactoryProtocol
    let lockStateFactory: GovernanceLockStateFactoryProtocol
    let connection: JSONRPCEngine
    let runtimeProvider: RuntimeProviderProtocol
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
        walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol,
        priceLocalSubscriptionFactory: PriceProviderFactoryProtocol,
        blockTimeService: BlockTimeEstimationServiceProtocol,
        blockTimeFactory: BlockTimeOperationFactoryProtocol,
        connection: JSONRPCEngine,
        runtimeProvider: RuntimeProviderProtocol,
        currencyManager: CurrencyManagerProtocol,
        extrinsicFactory: GovernanceExtrinsicFactoryProtocol,
        extrinsicService: ExtrinsicServiceProtocol,
        feeProxy: MultiExtrinsicFeeProxyProtocol,
        lockStateFactory: GovernanceLockStateFactoryProtocol,
        chainRegistry: ChainRegistryProtocol,
        operationQueue: OperationQueue
    ) {
        self.selectedAccount = selectedAccount
        self.chain = chain
        self.generalLocalSubscriptionFactory = generalLocalSubscriptionFactory
        self.blockTimeService = blockTimeService
        self.blockTimeFactory = blockTimeFactory
        self.connection = connection
        self.runtimeProvider = runtimeProvider
        self.walletLocalSubscriptionFactory = walletLocalSubscriptionFactory
        self.priceLocalSubscriptionFactory = priceLocalSubscriptionFactory
        self.extrinsicFactory = extrinsicFactory
        self.extrinsicService = extrinsicService
        self.feeProxy = feeProxy
        self.lockStateFactory = lockStateFactory
        self.chainRegistry = chainRegistry
        self.operationQueue = operationQueue
        self.currencyManager = currencyManager
    }

    deinit {
        clearCancellable()
    }

    private func clearCancellable() {
        clear(cancellable: &blockTimeCancellable)
        clear(cancellable: &lockDiffCancellable)
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

    func makeSubscriptions() {
        clearAndSubscribeBalance()
        clearAndSubscribePrice()
        clearAndSubscribeBlockNumber()
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

    func createExtrinsicSplitter(for votes: [ReferendumNewVote]) -> ExtrinsicSplitting {
        let splitter = ExtrinsicSplitter(
            chain: chain,
            maxCallsPerExtrinsic: selectedAccount.chainAccount.type.maxCallsPerExtrinsic,
            chainRegistry: chainRegistry,
            operationQueue: operationQueue
        )

        return extrinsicFactory.vote(using: votes, splitter: splitter)
    }
}

extension ReferendumVoteInteractor: ReferendumVoteInteractorInputProtocol {
    func estimateFee(for votes: [ReferendumNewVote]) {
        guard let actionHash = votes.first?.voteAction.hashValue else {
            return
        }

        let reuseIdentifier = "\(actionHash)"

        let splitter = createExtrinsicSplitter(for: votes)

        feeProxy.estimateFee(
            from: splitter,
            service: extrinsicService,
            reuseIdentifier: reuseIdentifier,
            payingIn: nil
        )
    }

    func refreshLockDiff(
        for trackVoting: ReferendumTracksVotingDistribution,
        newVotes: [ReferendumNewVote]
    ) {
        clear(cancellable: &lockDiffCancellable)

        let wrapper = lockStateFactory.calculateLockStateDiff(
            for: trackVoting,
            newVotes: newVotes,
            from: connection,
            runtimeProvider: runtimeProvider,
            blockHash: nil
        )

        wrapper.targetOperation.completionBlock = { [weak self] in
            DispatchQueue.main.async {
                guard wrapper === self?.lockDiffCancellable else {
                    return
                }

                self?.lockDiffCancellable = nil

                do {
                    let stateDiff = try wrapper.targetOperation.extractNoCancellableResultData()
                    self?.basePresenter?.didReceiveLockStateDiff(stateDiff)
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

extension ReferendumVoteInteractor: WalletLocalSubscriptionHandler, WalletLocalStorageSubscriber {
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

extension ReferendumVoteInteractor: PriceLocalSubscriptionHandler, PriceLocalStorageSubscriber {
    func handlePrice(result: Result<PriceData?, Error>, priceId _: AssetModel.PriceId) {
        switch result {
        case let .success(price):
            basePresenter?.didReceivePrice(price)
        case let .failure(error):
            basePresenter?.didReceiveBaseError(.priceFailed(error))
        }
    }
}

extension ReferendumVoteInteractor: MultiExtrinsicFeeProxyDelegate {
    func didReceiveTotalFee(
        result: Result<any ExtrinsicFeeProtocol, any Error>,
        for _: TransactionFeeId
    ) {
        switch result {
        case let .success(feeInfo):
            basePresenter?.didReceiveFee(feeInfo)
        case let .failure(error):
            basePresenter?.didReceiveBaseError(.feeFailed(error))
        }
    }
}

extension ReferendumVoteInteractor: GeneralLocalStorageSubscriber, GeneralLocalStorageHandler {
    func handleBlockNumber(result: Result<BlockNumber?, Error>, chainId _: ChainModel.Id) {
        switch result {
        case let .success(blockNumber):
            if let blockNumber = blockNumber {
                basePresenter?.didReceiveBlockNumber(blockNumber)
            }
        case let .failure(error):
            basePresenter?.didReceiveBaseError(.blockNumberSubscriptionFailed(error))
        }
    }
}

extension ReferendumVoteInteractor: SelectedCurrencyDepending {
    func applyCurrency() {
        guard basePresenter != nil else {
            return
        }

        clearAndSubscribePrice()
    }
}

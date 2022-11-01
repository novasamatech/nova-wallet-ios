import Foundation
import SubstrateSdk
import RobinHood

class GovernanceUnlockInteractor: GovernanceUnlockInteractorInputProtocol, AnyCancellableCleaning {
    weak var basePresenter: GovernanceUnlockInteractorOutputProtocol?

    let chain: ChainModel
    let selectedAccount: MetaChainAccountResponse
    let subscriptionFactory: GovernanceSubscriptionFactoryProtocol
    let lockStateFactory: GovernanceLockStateFactoryProtocol
    let priceLocalSubscriptionFactory: PriceProviderFactoryProtocol
    let generalLocalSubscriptionFactory: GeneralStorageSubscriptionFactoryProtocol
    let blockTimeService: BlockTimeEstimationServiceProtocol
    let connection: JSONRPCEngine
    let runtimeProvider: RuntimeProviderProtocol
    let operationQueue: OperationQueue

    private var priceProvider: AnySingleValueProvider<PriceData>?
    private var blockNumberProvider: AnyDataProvider<DecodedBlockNumber>?

    private var blockTimeCancellable: CancellableCall?
    private var unlockScheduleCancellable: CancellableCall?

    init(
        chain: ChainModel,
        selectedAccount: MetaChainAccountResponse,
        subscriptionFactory: GovernanceSubscriptionFactoryProtocol,
        lockStateFactory: GovernanceLockStateFactoryProtocol,
        priceLocalSubscriptionFactory: PriceProviderFactoryProtocol,
        generalLocalSubscriptionFactory: GeneralStorageSubscriptionFactoryProtocol,
        blockTimeService: BlockTimeEstimationServiceProtocol,
        connection: JSONRPCEngine,
        runtimeProvider: RuntimeProviderProtocol,
        operationQueue: OperationQueue
    ) {
        self.chain = chain
        self.selectedAccount = selectedAccount
        self.subscriptionFactory = subscriptionFactory
        self.lockStateFactory = lockStateFactory
        self.priceLocalSubscriptionFactory = priceLocalSubscriptionFactory
        self.generalLocalSubscriptionFactory = generalLocalSubscriptionFactory
        self.blockTimeService = blockTimeService
        self.connection = connection
        self.runtimeProvider = runtimeProvider
        self.operationQueue = operationQueue
    }

    deinit {
        clearVotingSubscription()
        clearCancellable()
    }

    private func clearCancellable() {
        clear(cancellable: &blockTimeCancellable)
        clear(cancellable: &unlockScheduleCancellable)
    }

    private func provideBlockTime() {
        guard blockTimeCancellable == nil else {
            return
        }

        let operation = blockTimeService.createEstimatedBlockTimeOperation()

        operation.completionBlock = { [weak self] in
            DispatchQueue.main.async {
                guard operation === self?.blockTimeCancellable else {
                    return
                }

                self?.blockTimeCancellable = nil

                do {
                    let blockTimeModel = try operation.extractNoCancellableResultData()
                    self?.basePresenter?.didReceiveBlockTime(blockTimeModel.blockTime)
                } catch {
                    self?.basePresenter?.didReceiveBaseError(.blockTimeFetchFailed(error))
                }
            }
        }

        blockTimeCancellable = operation

        operationQueue.addOperation(operation)
    }

    func provideUnlockSchedule(for tracksVoting: ReferendumTracksVotingDistribution, blockHash: Data?) {
        clear(cancellable: &unlockScheduleCancellable)

        let wrapper = lockStateFactory.buildUnlockScheduleWrapper(
            for: tracksVoting,
            from: connection,
            runtimeProvider: runtimeProvider,
            blockHash: blockHash
        )

        wrapper.targetOperation.completionBlock = { [weak self] in
            DispatchQueue.main.async {
                guard self?.unlockScheduleCancellable === wrapper else {
                    return
                }

                self?.unlockScheduleCancellable = nil

                do {
                    let schedule = try wrapper.targetOperation.extractNoCancellableResultData()
                    self?.basePresenter?.didReceiveUnlockSchedule(schedule)
                } catch {
                    self?.basePresenter?.didReceiveBaseError(.unlockScheduleFetchFailed(error))
                }
            }
        }

        unlockScheduleCancellable = wrapper

        operationQueue.addOperations(wrapper.allOperations, waitUntilFinished: false)
    }

    private func clearVotingSubscription() {
        subscriptionFactory.unsubscribeFromAccountVotes(self, accountId: selectedAccount.chainAccount.accountId)
    }

    private func subscribeVoting() {
        subscriptionFactory.subscribeToAccountVotes(
            self,
            accountId: selectedAccount.chainAccount.accountId
        ) { [weak self] result in
            switch result {
            case let .success(storageResult):
                self?.basePresenter?.didReceiveVoting(storageResult)
            case let .failure(error):
                self?.basePresenter?.didReceiveBaseError(.votingSubscriptionFailed(error))
            case .none:
                self?.basePresenter?.didReceiveVoting(.init(value: nil, blockHash: nil))
            }
        }
    }

    private func clearAndSubscribeBlockNumber() {
        blockNumberProvider?.removeObserver(self)
        blockNumberProvider = nil

        blockNumberProvider = subscribeToBlockNumber(for: chain.chainId)
    }

    private func clearAndSubscribePrice() {
        priceProvider?.removeObserver(self)
        priceProvider = nil

        if let priceId = chain.utilityAsset()?.priceId {
            priceProvider = subscribeToPrice(for: priceId, currency: selectedCurrency)
        }
    }

    private func makeSubscriptions() {
        clearAndSubscribePrice()
        clearAndSubscribeBlockNumber()

        clearVotingSubscription()
        subscribeVoting()
    }

    func setup() {
        makeSubscriptions()
    }

    func refreshBlockTime() {
        provideBlockTime()
    }

    func refreshUnlockSchedule(for tracksVoting: ReferendumTracksVotingDistribution, blockHash: Data?) {
        provideUnlockSchedule(for: tracksVoting, blockHash: blockHash)
    }

    func remakeSubscriptions() {
        makeSubscriptions()
    }
}

extension GovernanceUnlockInteractor: PriceLocalSubscriptionHandler, PriceLocalStorageSubscriber {
    func handlePrice(result: Result<PriceData?, Error>, priceId _: AssetModel.PriceId) {
        switch result {
        case let .success(price):
            basePresenter?.didReceivePrice(price)
        case let .failure(error):
            basePresenter?.didReceiveBaseError(.priceSubscriptionFailed(error))
        }
    }
}

extension GovernanceUnlockInteractor: GeneralLocalStorageSubscriber, GeneralLocalStorageHandler {
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

extension GovernanceUnlockInteractor: SelectedCurrencyDepending {
    func applyCurrency() {
        guard basePresenter != nil else {
            return
        }

        clearAndSubscribePrice()
    }
}

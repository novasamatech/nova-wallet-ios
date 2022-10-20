import UIKit
import SubstrateSdk
import RobinHood

final class ReferendumVoteSetupInteractor: ReferendumVoteInteractor, AnyCancellableCleaning {
    weak var presenter: ReferendumVoteSetupInteractorOutputProtocol? {
        get {
            basePresenter as? ReferendumVoteSetupInteractorOutputProtocol
        }

        set {
            basePresenter = newValue
        }
    }

    let generalLocalSubscriptionFactory: GeneralStorageSubscriptionFactoryProtocol
    let blockTimeService: BlockTimeEstimationServiceProtocol
    let lockStateFactory: GovernanceLockStateFactoryProtocol
    let connection: JSONRPCEngine
    let runtimeProvider: RuntimeProviderProtocol
    let operationQueue: OperationQueue

    private var blockNumberSubscription: AnyDataProvider<DecodedBlockNumber>?

    private var blockTimeCancellable: CancellableCall?
    private var lockDiffCancellable: CancellableCall?

    init(
        referendumIndex: ReferendumIdLocal,
        selectedAccount: MetaChainAccountResponse,
        chain: ChainModel,
        generalLocalSubscriptionFactory: GeneralStorageSubscriptionFactoryProtocol,
        referendumsSubscriptionFactory: GovernanceSubscriptionFactoryProtocol,
        walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol,
        priceLocalSubscriptionFactory: PriceProviderFactoryProtocol,
        blockTimeService: BlockTimeEstimationServiceProtocol,
        connection: JSONRPCEngine,
        runtimeProvider: RuntimeProviderProtocol,
        currencyManager: CurrencyManagerProtocol,
        extrinsicFactory: GovernanceExtrinsicFactoryProtocol,
        extrinsicService: ExtrinsicServiceProtocol,
        feeProxy: ExtrinsicFeeProxyProtocol,
        lockStateFactory: GovernanceLockStateFactoryProtocol,
        operationQueue: OperationQueue
    ) {
        self.generalLocalSubscriptionFactory = generalLocalSubscriptionFactory
        self.blockTimeService = blockTimeService
        self.connection = connection
        self.runtimeProvider = runtimeProvider
        self.lockStateFactory = lockStateFactory
        self.operationQueue = operationQueue

        super.init(
            referendumIndex: referendumIndex,
            selectedAccount: selectedAccount,
            chain: chain,
            referendumsSubscriptionFactory: referendumsSubscriptionFactory,
            walletLocalSubscriptionFactory: walletLocalSubscriptionFactory,
            priceLocalSubscriptionFactory: priceLocalSubscriptionFactory,
            extrinsicFactory: extrinsicFactory,
            extrinsicService: extrinsicService,
            feeProxy: feeProxy,
            currencyManager: currencyManager
        )
    }

    deinit {
        clearReferendumSubscriptions()
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

        let operation = blockTimeService.createEstimatedBlockTimeOperation()

        operation.completionBlock = { [weak self] in
            DispatchQueue.main.async {
                guard operation === self?.blockTimeCancellable else {
                    return
                }

                self?.blockTimeCancellable = nil

                do {
                    let blockTimeModel = try operation.extractNoCancellableResultData()
                    self?.presenter?.didReceiveBlockTime(blockTimeModel.blockTime)
                } catch {
                    self?.presenter?.didReceiveError(.blockTimeFailed(error))
                }
            }
        }

        blockTimeCancellable = operation

        operationQueue.addOperation(operation)
    }

    private func clearReferendumSubscriptions() {
        referendumsSubscriptionFactory.unsubscribeFromAccountVotes(
            self,
            accountId: selectedAccount.chainAccount.accountId
        )
    }

    private func clearAndSubscribeBlockNumber() {
        blockNumberSubscription?.removeObserver(self)
        blockNumberSubscription = nil

        blockNumberSubscription = subscribeToBlockNumber(for: chain.chainId)
    }

    private func subscribeAccountVotes() {
        clearReferendumSubscriptions()

        referendumsSubscriptionFactory.subscribeToAccountVotes(
            self,
            accountId: selectedAccount.chainAccount.accountId
        ) { [weak self] result in
            switch result {
            case let .success(storageResult):
                self?.presenter?.didReceiveAccountVotes(storageResult)
            case let .failure(error):
                self?.presenter?.didReceiveError(.accountVotesFailed(error))
            case .none:
                self?.presenter?.didReceiveAccountVotes(.init(value: nil, blockHash: nil))
            }
        }
    }

    private func makeSubscriptions() {
        clearAndSubscribeBlockNumber()
    }

    override func setup() {
        super.setup()

        makeSubscriptions()
    }

    override func remakeSubscriptions() {
        super.remakeSubscriptions()

        makeSubscriptions()
    }
}

extension ReferendumVoteSetupInteractor: ReferendumVoteSetupInteractorInputProtocol {
    func refreshLockDiff(
        for votes: [ReferendumIdLocal: ReferendumAccountVoteLocal],
        newVote: ReferendumNewVote?,
        blockHash: Data?
    ) {
        clear(cancellable: &lockDiffCancellable)

        let wrapper = lockStateFactory.calculateLockStateDiff(
            for: votes,
            newVote: newVote,
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
                    self?.presenter?.didReceiveError(.stateDiffFailed(error))
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

extension ReferendumVoteSetupInteractor: GeneralLocalStorageSubscriber, GeneralLocalStorageHandler {
    func handleBlockNumber(result: Result<BlockNumber?, Error>, chainId _: ChainModel.Id) {
        switch result {
        case let .success(blockNumber):
            if let blockNumber = blockNumber {
                presenter?.didReceiveBlockNumber(blockNumber)
            }
        case let .failure(error):
            presenter?.didReceiveError(.blockNumberSubscriptionFailed(error))
        }
    }
}

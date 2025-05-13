import Operation_iOS
import Foundation_iOS
import SubstrateSdk

final class SwipeGovReferendumDetailsInteractor {
    weak var presenter: SwipeGovReferendumDetailsInteractorOutputProtocol?

    let generalLocalSubscriptionFactory: GeneralStorageSubscriptionFactoryProtocol
    let referendumsSubscriptionFactory: GovernanceSubscriptionFactoryProtocol
    let govMetadataLocalSubscriptionFactory: GovMetadataLocalSubscriptionFactoryProtocol

    private let option: GovernanceSelectedOption
    private let actionDetailsOperationFactory: ReferendumActionOperationFactoryProtocol
    private let spendingAmountExtractor: GovSpendingExtracting
    private let connection: JSONRPCEngine
    private let runtimeProvider: RuntimeProviderProtocol
    private let identityProxyFactory: IdentityProxyFactoryProtocol
    private let blockTimeService: BlockTimeEstimationServiceProtocol
    private let blockTimeFactory: BlockTimeOperationFactoryProtocol

    private let operationQueue: OperationQueue

    private var referendum: ReferendumLocal
    private var actionDetails: ReferendumActionLocal?
    private var selectedAccount: ChainAccountResponse?

    private var metadataProvider: StreamableProvider<ReferendumMetadataLocal>?
    private var blockNumberSubscription: AnyDataProvider<DecodedBlockNumber>?

    private var identitiesCancellable = CancellableCallStore()
    private var actionDetailsCancellable = CancellableCallStore()
    private var blockTimeCancellable = CancellableCallStore()

    var chain: ChainModel {
        option.chain
    }

    init(
        referendum: ReferendumLocal,
        selectedAccount: ChainAccountResponse?,
        option: GovernanceSelectedOption,
        actionDetailsOperationFactory: ReferendumActionOperationFactoryProtocol,
        spendingAmountExtractor: GovSpendingExtracting,
        connection: JSONRPCEngine,
        runtimeProvider: RuntimeProviderProtocol,
        blockTimeService: BlockTimeEstimationServiceProtocol,
        blockTimeFactory: BlockTimeOperationFactoryProtocol,
        identityProxyFactory: IdentityProxyFactoryProtocol,
        generalLocalSubscriptionFactory: GeneralStorageSubscriptionFactoryProtocol,
        govMetadataLocalSubscriptionFactory: GovMetadataLocalSubscriptionFactoryProtocol,
        referendumsSubscriptionFactory: GovernanceSubscriptionFactoryProtocol,
        operationQueue: OperationQueue
    ) {
        self.referendum = referendum
        self.selectedAccount = selectedAccount
        self.option = option
        self.actionDetailsOperationFactory = actionDetailsOperationFactory
        self.spendingAmountExtractor = spendingAmountExtractor
        self.connection = connection
        self.runtimeProvider = runtimeProvider
        self.identityProxyFactory = identityProxyFactory
        self.generalLocalSubscriptionFactory = generalLocalSubscriptionFactory
        self.blockTimeService = blockTimeService
        self.blockTimeFactory = blockTimeFactory
        self.govMetadataLocalSubscriptionFactory = govMetadataLocalSubscriptionFactory
        self.referendumsSubscriptionFactory = referendumsSubscriptionFactory
        self.operationQueue = operationQueue
    }

    deinit {
        identitiesCancellable.cancel()
        actionDetailsCancellable.cancel()
        blockTimeCancellable.cancel()

        referendumsSubscriptionFactory.unsubscribeFromReferendum(self, referendumIndex: referendum.index)

        if let accountId = selectedAccount?.accountId {
            referendumsSubscriptionFactory.unsubscribeFromAccountVotes(self, accountId: accountId)
        }
    }
}

// MARK: SwipeGovReferendumDetailsInteractorInputProtocol

extension SwipeGovReferendumDetailsInteractor: SwipeGovReferendumDetailsInteractorInputProtocol {
    func setup() {
        makeSubscriptions()
        updateActionDetails()
    }

    func refreshBlockTime() {
        provideBlockTime()
    }

    func refreshActionDetails() {
        updateActionDetails()
    }

    func refreshIdentities(for accountIds: Set<AccountId>) {
        provideIdentities(for: accountIds)
    }

    func remakeSubscriptions() {
        metadataProvider?.removeObserver(self)
        metadataProvider = nil

        blockNumberSubscription?.removeObserver(self)
        blockNumberSubscription = nil

        makeSubscriptions()
    }
}

// MARK: GeneralLocalStorageSubscriber

extension SwipeGovReferendumDetailsInteractor: GeneralLocalStorageSubscriber, GeneralLocalStorageHandler {
    func handleBlockNumber(
        result: Result<BlockNumber?, Error>,
        chainId _: ChainModel.Id
    ) {
        switch result {
        case let .success(blockNumber):
            if let blockNumber = blockNumber {
                presenter?.didReceiveBlockNumber(blockNumber)
            }
        case let .failure(error):
            presenter?.didReceiveError(.blockNumberFailed(error))
        }
    }
}

// MARK: GovMetadataLocalStorageSubscriber

extension SwipeGovReferendumDetailsInteractor: GovMetadataLocalStorageSubscriber, GovMetadataLocalStorageHandler {
    func handleGovernanceMetadataDetails(
        result: Result<ReferendumMetadataLocal?, Error>,
        option _: GovernanceSelectedOption,
        referendumId _: ReferendumIdLocal
    ) {
        switch result {
        case let .success(metadata):
            presenter?.didReceiveMetadata(metadata)
        case let .failure(error):
            presenter?.didReceiveError(.metadataFailed(error))
        }
    }
}

// MARK: Private

private extension SwipeGovReferendumDetailsInteractor {
    func subscribeReferendum() {
        referendumsSubscriptionFactory.unsubscribeFromReferendum(self, referendumIndex: referendum.index)
        referendumsSubscriptionFactory.subscribeToReferendum(
            self,
            referendumIndex: referendum.index
        ) { [weak self] result in
            switch result {
            case let .success(referendumResult):
                if let referendum = referendumResult.value {
                    self?.referendum = referendum
                    self?.presenter?.didReceiveReferendum(referendum)
                }
            case let .failure(error):
                self?.presenter?.didReceiveError(.referendumFailed(error))
            case .none:
                break
            }
        }
    }

    func provideIdentities(for accountIds: Set<AccountId>) {
        identitiesCancellable.cancel()

        guard !accountIds.isEmpty else {
            presenter?.didReceiveIdentities([:])
            return
        }

        let accountIdsClosure: () throws -> [AccountId] = { Array(accountIds) }

        let wrapper = identityProxyFactory.createIdentityWrapper(for: accountIdsClosure)

        executeCancellable(
            wrapper: wrapper,
            inOperationQueue: operationQueue,
            backingCallIn: identitiesCancellable,
            runningCallbackIn: .main
        ) { [weak self] result in
            switch result {
            case let .success(identities):
                self?.presenter?.didReceiveIdentities(identities)
            case let .failure(error):
                self?.presenter?.didReceiveError(.identitiesFailed(error))
            }
        }
    }

    func provideBlockTime() {
        guard !blockTimeCancellable.hasCall else {
            return
        }

        let wrapper = blockTimeFactory.createBlockTimeOperation(
            from: runtimeProvider,
            blockTimeEstimationService: blockTimeService
        )

        executeCancellable(
            wrapper: wrapper,
            inOperationQueue: operationQueue,
            backingCallIn: blockTimeCancellable,
            runningCallbackIn: .main
        ) { [weak self] result in
            switch result {
            case let .success(blockTimeModel):
                self?.presenter?.didReceiveBlockTime(blockTimeModel)
            case let .failure(error):
                self?.presenter?.didReceiveError(.blockTimeFailed(error))
            }
        }
    }

    func updateActionDetails() {
        guard !actionDetailsCancellable.hasCall else {
            return
        }

        let wrapper = actionDetailsOperationFactory.fetchActionWrapper(
            for: referendum,
            connection: connection,
            runtimeProvider: runtimeProvider,
            spendAmountExtractor: spendingAmountExtractor
        )

        executeCancellable(
            wrapper: wrapper,
            inOperationQueue: operationQueue,
            backingCallIn: actionDetailsCancellable,
            runningCallbackIn: .main
        ) { [weak self] result in
            switch result {
            case let .success(actionDetails):
                self?.presenter?.didReceiveActionDetails(actionDetails)
            case let .failure(error):
                self?.presenter?.didReceiveError(.actionDetailsFailed(error))
            }
        }
    }

    func makeSubscriptions() {
        blockNumberSubscription = subscribeToBlockNumber(for: chain.chainId)

        subscribeReferendum()

        metadataProvider = subscribeGovernanceMetadata(for: option, referendumId: referendum.index)

        if metadataProvider == nil {
            presenter?.didReceiveMetadata(nil)
        } else {
            metadataProvider?.refresh()
        }
    }
}

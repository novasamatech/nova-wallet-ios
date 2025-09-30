import UIKit
import SubstrateSdk
import Operation_iOS

final class ReferendumDetailsInteractor: AnyProviderAutoCleaning {
    weak var presenter: ReferendumDetailsInteractorOutputProtocol?

    private(set) var referendum: ReferendumLocal
    private(set) var actionDetails: ReferendumActionLocal?

    let selectedAccount: ChainAccountResponse?
    let option: GovernanceSelectedOption
    let actionDetailsOperationFactory: ReferendumActionOperationFactoryProtocol
    let connection: JSONRPCEngine
    let runtimeProvider: RuntimeProviderProtocol
    let identityProxyFactory: IdentityProxyFactoryProtocol
    let timelineService: ChainTimelineFacadeProtocol
    let priceLocalSubscriptionFactory: PriceProviderFactoryProtocol
    let generalLocalSubscriptionFactory: GeneralStorageSubscriptionFactoryProtocol
    let referendumsSubscriptionFactory: GovernanceSubscriptionFactoryProtocol
    let govMetadataLocalSubscriptionFactory: GovMetadataLocalSubscriptionFactoryProtocol
    let totalVotesFactory: GovernanceTotalVotesFactoryProtocol?
    let dAppsProvider: AnySingleValueProvider<GovernanceDAppList>
    let spendingAmountExtractor: GovSpendingExtracting
    let operationQueue: OperationQueue

    private var actionPriceProvider: StreamableProvider<PriceData>?
    private var metadataProvider: StreamableProvider<ReferendumMetadataLocal>?
    private var blockNumberSubscription: AnyDataProvider<DecodedBlockNumber>?

    private var identitiesCancellable = CancellableCallStore()
    private var actionDetailsCancellable = CancellableCallStore()
    private var blockTimeCancellable = CancellableCallStore()
    private var abstainsFetchCancellable = CancellableCallStore()
    private var allVotesFetchCancellable = CancellableCallStore()

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
        timelineService: ChainTimelineFacadeProtocol,
        identityProxyFactory: IdentityProxyFactoryProtocol,
        priceLocalSubscriptionFactory: PriceProviderFactoryProtocol,
        generalLocalSubscriptionFactory: GeneralStorageSubscriptionFactoryProtocol,
        govMetadataLocalSubscriptionFactory: GovMetadataLocalSubscriptionFactoryProtocol,
        referendumsSubscriptionFactory: GovernanceSubscriptionFactoryProtocol,
        totalVotesFactory: GovernanceTotalVotesFactoryProtocol?,
        dAppsProvider: AnySingleValueProvider<GovernanceDAppList>,
        currencyManager: CurrencyManagerProtocol,
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
        self.priceLocalSubscriptionFactory = priceLocalSubscriptionFactory
        self.generalLocalSubscriptionFactory = generalLocalSubscriptionFactory
        self.timelineService = timelineService
        self.govMetadataLocalSubscriptionFactory = govMetadataLocalSubscriptionFactory
        self.referendumsSubscriptionFactory = referendumsSubscriptionFactory
        self.totalVotesFactory = totalVotesFactory
        self.dAppsProvider = dAppsProvider
        self.operationQueue = operationQueue
        self.currencyManager = currencyManager
    }

    deinit {
        identitiesCancellable.cancel()
        actionDetailsCancellable.cancel()
        blockTimeCancellable.cancel()
        abstainsFetchCancellable.cancel()
        allVotesFetchCancellable.cancel()

        referendumsSubscriptionFactory.unsubscribeFromReferendum(self, referendumIndex: referendum.index)

        if let accountId = selectedAccount?.accountId {
            referendumsSubscriptionFactory.unsubscribeFromAccountVotes(self, accountId: accountId)
        }
    }

    private func subscribeReferendum() {
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

                    if referendum.state.completed {
                        self?.provideAllVotes()
                    } else {
                        self?.provideAbstains()
                    }
                }
            case let .failure(error):
                self?.presenter?.didReceiveError(.referendumFailed(error))
            case .none:
                break
            }
        }
    }

    private func subscribeAccountVotes() {
        guard let accountId = selectedAccount?.accountId else {
            presenter?.didReceiveAccountVotes(nil, votingDistribution: nil)
            return
        }

        referendumsSubscriptionFactory.unsubscribeFromAccountVotes(self, accountId: accountId)

        referendumsSubscriptionFactory.subscribeToAccountVotes(
            self,
            accountId: accountId
        ) { [weak self] result in
            switch result {
            case let .success(votesResult):
                if let votes = votesResult.value?.votes.votes, let referendumId = self?.referendum.index {
                    self?.presenter?.didReceiveAccountVotes(
                        votes[referendumId],
                        votingDistribution: votesResult
                    )
                }
            case let .failure(error):
                self?.presenter?.didReceiveError(.accountVotesFailed(error))
            case .none:
                break
            }
        }
    }

    private func updatePriceSubscription(for chainAsset: ChainAsset?) {
        clear(streamableProvider: &actionPriceProvider)

        guard let priceId = chainAsset?.asset.priceId else {
            return
        }

        actionPriceProvider = subscribeToPrice(for: priceId, currency: selectedCurrency)
    }

    private func handleDAppsUpdate(_ updatedDApps: GovernanceDAppList) {
        let chainDApps = updatedDApps.first(where: { $0.chainId == chain.chainId })?.dapps ?? []
        let versionDApps = chainDApps.filter { $0.supports(governanceType: option.type) }
        presenter?.didReceiveDApps(versionDApps)
    }

    private func subscribeDApps() {
        dAppsProvider.removeObserver(self)

        let options = DataProviderObserverOptions(
            alwaysNotifyOnRefresh: false,
            waitsInProgressSyncOnAdd: false
        )

        let updateClosure: ([DataProviderChange<GovernanceDAppList>]) -> Void = { [weak self] changes in
            if let result = changes.reduceToLastChange() {
                self?.handleDAppsUpdate(result)
            } else {
                self?.presenter?.didReceiveDApps([])
            }
        }

        let failureClosure: (Error) -> Void = { [weak self] error in
            self?.presenter?.didReceiveError(.dAppsFailed(error))
        }

        dAppsProvider.addObserver(
            self,
            deliverOn: .main,
            executing: updateClosure,
            failing: failureClosure,
            options: options
        )
    }

    private func provideIdentities(for accountIds: Set<AccountId>) {
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

    private func provideBlockTime() {
        guard !blockTimeCancellable.hasCall else {
            return
        }

        let wrapper = timelineService.createBlockTimeOperation()

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

    private func updateActionDetails() {
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
            guard let self else {
                return
            }

            switch result {
            case let .success(actionDetails):
                if let actionAsset = actionDetails.requestedAmount()?.otherChainAssetOrCurrentUtility(
                    from: self.chain
                ) {
                    updatePriceSubscription(for: actionAsset)
                }

                self.presenter?.didReceiveActionDetails(actionDetails)
            case let .failure(error):
                self.presenter?.didReceiveError(.actionDetailsFailed(error))
            }
        }
    }

    private func makeAccountBasedSubscriptions() {
        subscribeAccountVotes()
    }

    private func makeSubscriptions() {
        blockNumberSubscription = subscribeToBlockNumber(for: timelineService.timelineChainId)

        subscribeReferendum()

        makeAccountBasedSubscriptions()

        metadataProvider = subscribeGovernanceMetadata(for: option, referendumId: referendum.index)

        if metadataProvider == nil {
            presenter?.didReceiveMetadata(nil)
        } else {
            metadataProvider?.refresh()
        }
    }

    private func provideAbstains() {
        guard
            !abstainsFetchCancellable.hasCall,
            let totalVotesFactory
        else {
            return
        }

        let operation = totalVotesFactory.createOperation(
            referendumId: referendum.index,
            votersType: .abstains
        )

        execute(
            operation: operation,
            inOperationQueue: operationQueue,
            backingCallIn: abstainsFetchCancellable,
            runningCallbackIn: .main
        ) { [weak self] result in
            switch result {
            case let .success(amount):
                self?.presenter?.didReceiveVotingAmount(amount)
            case let .failure(error):
                self?.presenter?.didReceiveError(.accountVotesFailed(error))
            }
        }
    }

    private func provideAllVotes() {
        guard
            !allVotesFetchCancellable.hasCall,
            let totalVotesFactory
        else {
            return
        }

        let operation = totalVotesFactory.createOperation(
            referendumId: referendum.index,
            votersType: nil
        )

        execute(
            operation: operation,
            inOperationQueue: operationQueue,
            backingCallIn: allVotesFetchCancellable,
            runningCallbackIn: .main
        ) { [weak self] result in
            switch result {
            case let .success(amount):
                self?.presenter?.didReceiveVotingAmount(amount)
            case let .failure(error):
                self?.presenter?.didReceiveError(.accountVotesFailed(error))
            }
        }
    }
}

extension ReferendumDetailsInteractor: ReferendumDetailsInteractorInputProtocol {
    func setup() {
        makeSubscriptions()
        updateActionDetails()
        subscribeDApps()
    }

    func remakeDAppsSubscription() {
        subscribeDApps()
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

extension ReferendumDetailsInteractor: GeneralLocalStorageSubscriber, GeneralLocalStorageHandler {
    func handleBlockNumber(result: Result<BlockNumber?, Error>, chainId _: ChainModel.Id) {
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

extension ReferendumDetailsInteractor: PriceLocalSubscriptionHandler, PriceLocalStorageSubscriber {
    func handlePrice(result: Result<PriceData?, Error>, priceId _: AssetModel.PriceId) {
        switch result {
        case let .success(price):
            presenter?.didReceiveRequestedAmountPrice(price)
        case let .failure(error):
            presenter?.didReceiveError(.priceFailed(error))
        }
    }
}

extension ReferendumDetailsInteractor: GovMetadataLocalStorageSubscriber, GovMetadataLocalStorageHandler {
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

extension ReferendumDetailsInteractor: SelectedCurrencyDepending {
    func applyCurrency() {
        if presenter != nil {
            updateActionDetails()
        }
    }
}

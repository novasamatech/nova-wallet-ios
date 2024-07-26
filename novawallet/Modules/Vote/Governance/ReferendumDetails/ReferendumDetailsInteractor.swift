import UIKit
import SubstrateSdk
import Operation_iOS

final class ReferendumDetailsInteractor {
    weak var presenter: ReferendumDetailsInteractorOutputProtocol?

    private(set) var referendum: ReferendumLocal
    private(set) var actionDetails: ReferendumActionLocal?

    let selectedAccount: ChainAccountResponse?
    let option: GovernanceSelectedOption
    let actionDetailsOperationFactory: ReferendumActionOperationFactoryProtocol
    let connection: JSONRPCEngine
    let runtimeProvider: RuntimeProviderProtocol
    let identityProxyFactory: IdentityProxyFactoryProtocol
    let blockTimeService: BlockTimeEstimationServiceProtocol
    let blockTimeFactory: BlockTimeOperationFactoryProtocol
    let priceLocalSubscriptionFactory: PriceProviderFactoryProtocol
    let generalLocalSubscriptionFactory: GeneralStorageSubscriptionFactoryProtocol
    let referendumsSubscriptionFactory: GovernanceSubscriptionFactoryProtocol
    let govMetadataLocalSubscriptionFactory: GovMetadataLocalSubscriptionFactoryProtocol
    let votersLocalWrapperFactory: ReferendumVotersLocalWrapperFactoryProtocol?
    let dAppsProvider: AnySingleValueProvider<GovernanceDAppList>
    let operationQueue: OperationQueue

    private var priceProvider: StreamableProvider<PriceData>?
    private var metadataProvider: StreamableProvider<ReferendumMetadataLocal>?
    private var blockNumberSubscription: AnyDataProvider<DecodedBlockNumber>?

    private var identitiesCancellable = CancellableCallStore()
    private var actionDetailsCancellable = CancellableCallStore()
    private var blockTimeCancellable = CancellableCallStore()
    private var abstainsFetchCancellable = CancellableCallStore()

    var chain: ChainModel {
        option.chain
    }

    init(
        referendum: ReferendumLocal,
        selectedAccount: ChainAccountResponse?,
        option: GovernanceSelectedOption,
        actionDetailsOperationFactory: ReferendumActionOperationFactoryProtocol,
        connection: JSONRPCEngine,
        runtimeProvider: RuntimeProviderProtocol,
        blockTimeService: BlockTimeEstimationServiceProtocol,
        blockTimeFactory: BlockTimeOperationFactoryProtocol,
        identityProxyFactory: IdentityProxyFactoryProtocol,
        priceLocalSubscriptionFactory: PriceProviderFactoryProtocol,
        generalLocalSubscriptionFactory: GeneralStorageSubscriptionFactoryProtocol,
        govMetadataLocalSubscriptionFactory: GovMetadataLocalSubscriptionFactoryProtocol,
        referendumsSubscriptionFactory: GovernanceSubscriptionFactoryProtocol,
        votersLocalWrapperFactory: ReferendumVotersLocalWrapperFactoryProtocol?,
        dAppsProvider: AnySingleValueProvider<GovernanceDAppList>,
        currencyManager: CurrencyManagerProtocol,
        operationQueue: OperationQueue
    ) {
        self.referendum = referendum
        self.selectedAccount = selectedAccount
        self.option = option
        self.actionDetailsOperationFactory = actionDetailsOperationFactory
        self.connection = connection
        self.runtimeProvider = runtimeProvider
        self.identityProxyFactory = identityProxyFactory
        self.priceLocalSubscriptionFactory = priceLocalSubscriptionFactory
        self.generalLocalSubscriptionFactory = generalLocalSubscriptionFactory
        self.blockTimeService = blockTimeService
        self.blockTimeFactory = blockTimeFactory
        self.govMetadataLocalSubscriptionFactory = govMetadataLocalSubscriptionFactory
        self.referendumsSubscriptionFactory = referendumsSubscriptionFactory
        self.votersLocalWrapperFactory = votersLocalWrapperFactory
        self.dAppsProvider = dAppsProvider
        self.operationQueue = operationQueue
        self.currencyManager = currencyManager
    }

    deinit {
        identitiesCancellable.clear()
        actionDetailsCancellable.clear()
        blockTimeCancellable.clear()
        abstainsFetchCancellable.clear()

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
                    self?.provideAbstains()
                    self?.presenter?.didReceiveReferendum(referendum)
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
        identitiesCancellable.clear()

        guard !accountIds.isEmpty else {
            presenter?.didReceiveIdentities([:])
            return
        }

        let accountIdsClosure: () throws -> [AccountId] = { Array(accountIds) }

        let wrapper = identityProxyFactory.createIdentityWrapper(for: accountIdsClosure)

        identitiesCancellable.store(call: wrapper)

        execute(
            wrapper: wrapper,
            inOperationQueue: operationQueue,
            runningCallbackIn: .main
        ) { [weak self] result in
            guard
                let self,
                identitiesCancellable.matches(call: wrapper)
            else {
                return
            }

            identitiesCancellable.clear()

            switch result {
            case let .success(identities):
                presenter?.didReceiveIdentities(identities)
            case let .failure(error):
                presenter?.didReceiveError(.identitiesFailed(error))
            }
        }
    }

    private func provideBlockTime() {
        guard !blockTimeCancellable.hasCall else {
            return
        }

        let wrapper = blockTimeFactory.createBlockTimeOperation(
            from: runtimeProvider,
            blockTimeEstimationService: blockTimeService
        )

        blockTimeCancellable.store(call: wrapper)

        execute(
            wrapper: wrapper,
            inOperationQueue: operationQueue,
            runningCallbackIn: .main
        ) { [weak self] result in
            guard
                let self,
                blockTimeCancellable.matches(call: wrapper)
            else {
                return
            }

            blockTimeCancellable.clear()

            switch result {
            case let .success(blockTimeModel):
                presenter?.didReceiveBlockTime(blockTimeModel)
            case let .failure(error):
                presenter?.didReceiveError(.blockTimeFailed(error))
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
            runtimeProvider: runtimeProvider
        )

        actionDetailsCancellable.store(call: wrapper)

        execute(
            wrapper: wrapper,
            inOperationQueue: operationQueue,
            runningCallbackIn: .main
        ) { [weak self] result in
            guard
                let self,
                actionDetailsCancellable.matches(call: wrapper)
            else {
                return
            }

            actionDetailsCancellable.clear()

            switch result {
            case let .success(actionDetails):
                presenter?.didReceiveActionDetails(actionDetails)
            case let .failure(error):
                presenter?.didReceiveError(.actionDetailsFailed(error))
            }
        }
    }

    private func makeAccountBasedSubscriptions() {
        subscribeAccountVotes()
    }

    private func makeSubscriptions() {
        if let priceId = chain.utilityAsset()?.priceId {
            priceProvider = subscribeToPrice(for: priceId, currency: selectedCurrency)
        }

        blockNumberSubscription = subscribeToBlockNumber(for: chain.chainId)

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
            let votersLocalWrapperFactory
        else {
            return
        }

        let wrapper = votersLocalWrapperFactory.createWrapper(
            for: .init(referendumId: referendum.index, votersType: .abstains)
        )

        abstainsFetchCancellable.store(call: wrapper)

        execute(
            wrapper: wrapper,
            inOperationQueue: operationQueue,
            runningCallbackIn: .main
        ) { [weak self] result in
            guard let self, abstainsFetchCancellable.matches(call: wrapper) else {
                return
            }

            abstainsFetchCancellable.clear()

            switch result {
            case let .success(voters):
                presenter?.didReceiveAbstains(voters)
            case let .failure(error):
                presenter?.didReceiveError(.accountVotesFailed(error))
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
        priceProvider?.removeObserver(self)
        priceProvider = nil

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
            presenter?.didReceivePrice(price)
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
            if let priceId = chain.utilityAsset()?.priceId {
                priceProvider = subscribeToPrice(for: priceId, currency: selectedCurrency)
            }
        }
    }
}

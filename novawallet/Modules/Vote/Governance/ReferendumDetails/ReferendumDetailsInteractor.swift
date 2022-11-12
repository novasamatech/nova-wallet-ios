import UIKit
import SubstrateSdk
import RobinHood

final class ReferendumDetailsInteractor: AnyCancellableCleaning {
    weak var presenter: ReferendumDetailsInteractorOutputProtocol?

    private(set) var referendum: ReferendumLocal
    private(set) var actionDetails: ReferendumActionLocal?

    let selectedAccount: ChainAccountResponse?
    let chain: ChainModel
    let actionDetailsOperationFactory: ReferendumActionOperationFactoryProtocol
    let connection: JSONRPCEngine
    let runtimeProvider: RuntimeProviderProtocol
    let identityOperationFactory: IdentityOperationFactoryProtocol
    let blockTimeService: BlockTimeEstimationServiceProtocol
    let blockTimeFactory: BlockTimeOperationFactoryProtocol
    let priceLocalSubscriptionFactory: PriceProviderFactoryProtocol
    let generalLocalSubscriptionFactory: GeneralStorageSubscriptionFactoryProtocol
    let referendumsSubscriptionFactory: GovernanceSubscriptionFactoryProtocol
    let govMetadataLocalSubscriptionFactory: GovMetadataLocalSubscriptionFactoryProtocol
    let dAppsProvider: AnySingleValueProvider<GovernanceDAppList>
    let operationQueue: OperationQueue

    private var priceProvider: AnySingleValueProvider<PriceData>?
    private var metadataProvider: StreamableProvider<ReferendumMetadataLocal>?
    private var blockNumberSubscription: AnyDataProvider<DecodedBlockNumber>?

    private var identitiesCancellable: CancellableCall?
    private var actionDetailsCancellable: CancellableCall?
    private var blockTimeCancellable: CancellableCall?
    private var dAppsCancellable: CancellableCall?

    init(
        referendum: ReferendumLocal,
        selectedAccount: ChainAccountResponse?,
        chain: ChainModel,
        actionDetailsOperationFactory: ReferendumActionOperationFactoryProtocol,
        connection: JSONRPCEngine,
        runtimeProvider: RuntimeProviderProtocol,
        blockTimeService: BlockTimeEstimationServiceProtocol,
        blockTimeFactory: BlockTimeOperationFactoryProtocol,
        identityOperationFactory: IdentityOperationFactoryProtocol,
        priceLocalSubscriptionFactory: PriceProviderFactoryProtocol,
        generalLocalSubscriptionFactory: GeneralStorageSubscriptionFactoryProtocol,
        govMetadataLocalSubscriptionFactory: GovMetadataLocalSubscriptionFactoryProtocol,
        referendumsSubscriptionFactory: GovernanceSubscriptionFactoryProtocol,
        dAppsProvider: AnySingleValueProvider<GovernanceDAppList>,
        currencyManager: CurrencyManagerProtocol,
        operationQueue: OperationQueue
    ) {
        self.referendum = referendum
        self.selectedAccount = selectedAccount
        self.chain = chain
        self.actionDetailsOperationFactory = actionDetailsOperationFactory
        self.connection = connection
        self.runtimeProvider = runtimeProvider
        self.identityOperationFactory = identityOperationFactory
        self.priceLocalSubscriptionFactory = priceLocalSubscriptionFactory
        self.generalLocalSubscriptionFactory = generalLocalSubscriptionFactory
        self.blockTimeService = blockTimeService
        self.blockTimeFactory = blockTimeFactory
        self.govMetadataLocalSubscriptionFactory = govMetadataLocalSubscriptionFactory
        self.referendumsSubscriptionFactory = referendumsSubscriptionFactory
        self.dAppsProvider = dAppsProvider
        self.operationQueue = operationQueue
        self.currencyManager = currencyManager
    }

    deinit {
        clear(cancellable: &identitiesCancellable)
        clear(cancellable: &actionDetailsCancellable)
        clear(cancellable: &blockTimeCancellable)
        clear(cancellable: &dAppsCancellable)

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
        let dApps = updatedDApps.first(where: { $0.chainId == chain.chainId })?.dapps ?? []
        presenter?.didReceiveDApps(dApps)
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
        clear(cancellable: &identitiesCancellable)

        guard !accountIds.isEmpty else {
            presenter?.didReceiveIdentities([:])
            return
        }

        let accountIdsClosure: () throws -> [AccountId] = { Array(accountIds) }

        let wrapper = identityOperationFactory.createIdentityWrapper(
            for: accountIdsClosure,
            engine: connection,
            runtimeService: runtimeProvider,
            chainFormat: chain.chainFormat
        )

        wrapper.targetOperation.completionBlock = { [weak self] in
            DispatchQueue.main.async {
                guard wrapper === self?.identitiesCancellable else {
                    return
                }

                self?.identitiesCancellable = nil

                do {
                    let identities = try wrapper.targetOperation.extractNoCancellableResultData()
                    self?.presenter?.didReceiveIdentities(identities)
                } catch {
                    self?.presenter?.didReceiveError(.identitiesFailed(error))
                }
            }
        }

        identitiesCancellable = wrapper

        operationQueue.addOperations(wrapper.allOperations, waitUntilFinished: false)
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
                    self?.presenter?.didReceiveBlockTime(blockTimeModel)
                } catch {
                    self?.presenter?.didReceiveError(.blockTimeFailed(error))
                }
            }
        }

        blockTimeCancellable = wrapper

        operationQueue.addOperations(wrapper.allOperations, waitUntilFinished: false)
    }

    private func updateActionDetails() {
        guard actionDetailsCancellable == nil else {
            return
        }

        let wrapper = actionDetailsOperationFactory.fetchActionWrapper(
            for: referendum,
            connection: connection,
            runtimeProvider: runtimeProvider
        )

        wrapper.targetOperation.completionBlock = { [weak self] in
            DispatchQueue.main.async {
                guard wrapper === self?.actionDetailsCancellable else {
                    return
                }

                self?.actionDetailsCancellable = nil

                do {
                    let actionDetails = try wrapper.targetOperation.extractNoCancellableResultData()
                    self?.actionDetails = actionDetails

                    self?.presenter?.didReceiveActionDetails(actionDetails)
                } catch {
                    self?.presenter?.didReceiveError(.actionDetailsFailed(error))
                }
            }
        }

        actionDetailsCancellable = wrapper

        operationQueue.addOperations(wrapper.allOperations, waitUntilFinished: false)
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

        metadataProvider = subscribeGovernanceMetadata(for: chain, referendumId: referendum.index)

        if metadataProvider == nil {
            presenter?.didReceiveMetadata(nil)
        } else {
            metadataProvider?.refresh()
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
        chain _: ChainModel,
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

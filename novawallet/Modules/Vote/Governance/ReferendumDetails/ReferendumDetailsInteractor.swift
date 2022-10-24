import UIKit
import SubstrateSdk
import RobinHood

final class ReferendumDetailsInteractor: AnyCancellableCleaning {
    weak var presenter: ReferendumDetailsInteractorOutputProtocol?

    private(set) var referendum: ReferendumLocal
    private(set) var actionDetails: ReferendumActionLocal?

    let selectedAccount: ChainAccountResponse
    let chain: ChainModel
    let actionDetailsOperationFactory: ReferendumActionOperationFactoryProtocol
    let connection: JSONRPCEngine
    let runtimeProvider: RuntimeProviderProtocol
    let identityOperationFactory: IdentityOperationFactoryProtocol
    let blockTimeService: BlockTimeEstimationServiceProtocol
    let priceLocalSubscriptionFactory: PriceProviderFactoryProtocol
    let generalLocalSubscriptionFactory: GeneralStorageSubscriptionFactoryProtocol
    let referendumsSubscriptionFactory: GovernanceSubscriptionFactoryProtocol
    let govMetadataLocalSubscriptionFactory: GovMetadataLocalSubscriptionFactoryProtocol
    let dAppsRepository: JsonFileRepository<[GovernanceDApp]>
    let operationQueue: OperationQueue

    private var priceProvider: AnySingleValueProvider<PriceData>?
    private var metadataProvider: AnySingleValueProvider<ReferendumMetadataMapping>?
    private var blockNumberSubscription: AnyDataProvider<DecodedBlockNumber>?

    private var identitiesCancellable: CancellableCall?
    private var actionDetailsCancellable: CancellableCall?
    private var blockTimeCancellable: CancellableCall?
    private var dAppsCancellable: CancellableCall?

    init(
        referendum: ReferendumLocal,
        selectedAccount: ChainAccountResponse,
        chain: ChainModel,
        actionDetailsOperationFactory: ReferendumActionOperationFactoryProtocol,
        connection: JSONRPCEngine,
        runtimeProvider: RuntimeProviderProtocol,
        blockTimeService: BlockTimeEstimationServiceProtocol,
        identityOperationFactory: IdentityOperationFactoryProtocol,
        priceLocalSubscriptionFactory: PriceProviderFactoryProtocol,
        generalLocalSubscriptionFactory: GeneralStorageSubscriptionFactoryProtocol,
        govMetadataLocalSubscriptionFactory: GovMetadataLocalSubscriptionFactoryProtocol,
        referendumsSubscriptionFactory: GovernanceSubscriptionFactoryProtocol,
        dAppsRepository: JsonFileRepository<[GovernanceDApp]>,
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
        self.govMetadataLocalSubscriptionFactory = govMetadataLocalSubscriptionFactory
        self.referendumsSubscriptionFactory = referendumsSubscriptionFactory
        self.dAppsRepository = dAppsRepository
        self.operationQueue = operationQueue
        self.currencyManager = currencyManager
    }

    deinit {
        clear(cancellable: &identitiesCancellable)
        clear(cancellable: &actionDetailsCancellable)
        clear(cancellable: &blockTimeCancellable)
        clear(cancellable: &dAppsCancellable)

        referendumsSubscriptionFactory.unsubscribeFromReferendum(self, referendumIndex: referendum.index)
        referendumsSubscriptionFactory.unsubscribeFromAccountVotes(self, accountId: selectedAccount.accountId)
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
        referendumsSubscriptionFactory.unsubscribeFromAccountVotes(self, accountId: selectedAccount.accountId)

        referendumsSubscriptionFactory.subscribeToAccountVotes(
            self,
            accountId: selectedAccount.accountId
        ) { [weak self] result in
            switch result {
            case let .success(votesResult):
                if let votes = votesResult.value?.votes.votes, let referendumId = self?.referendum.index {
                    self?.presenter?.didReceiveAccountVotes(votes[referendumId])
                }
            case let .failure(error):
                self?.presenter?.didReceiveError(.accountVotesFailed(error))
            case .none:
                break
            }
        }
    }

    private func provideDApps() {
        clear(cancellable: &dAppsCancellable)

        let wrapper = dAppsRepository.fetchOperationWrapper(
            by: R.file.governanceDAppsJson(),
            defaultValue: []
        )

        wrapper.targetOperation.completionBlock = { [weak self] in
            DispatchQueue.main.async {
                guard self?.dAppsCancellable === wrapper else {
                    return
                }

                self?.dAppsCancellable = nil

                do {
                    let dApps = try wrapper.targetOperation.extractNoCancellableResultData()
                    self?.presenter?.didReceiveDApps(dApps)
                } catch {
                    self?.presenter?.didReceiveError(.dAppsFailed(error))
                }
            }
        }

        dAppsCancellable = wrapper

        operationQueue.addOperations(wrapper.allOperations, waitUntilFinished: false)
    }

    private func provideIdentities() {
        clear(cancellable: &identitiesCancellable)

        var accountIds: [AccountId] = []

        if let proposer = referendum.proposer {
            accountIds.append(proposer)
        }

        if let beneficiary = actionDetails?.amountSpendDetails?.beneficiaryAccountId {
            accountIds.append(beneficiary)
        }

        guard !accountIds.isEmpty else {
            presenter?.didReceiveIdentities([:])
            return
        }

        let accountIdsClosure: () throws -> [AccountId] = { accountIds }

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

                    self?.provideIdentities()
                } catch {
                    self?.presenter?.didReceiveError(.actionDetailsFailed(error))
                }
            }
        }
    }

    private func makeSubscriptions() {
        if let priceId = chain.utilityAsset()?.priceId {
            priceProvider = subscribeToPrice(for: priceId, currency: selectedCurrency)
        }

        blockNumberSubscription = subscribeToBlockNumber(for: chain.chainId)

        subscribeReferendum()
        subscribeAccountVotes()

        metadataProvider = subscribeGovMetadata(for: chain)
    }
}

extension ReferendumDetailsInteractor: ReferendumDetailsInteractorInputProtocol {
    func setup() {
        makeSubscriptions()
        updateActionDetails()
        provideIdentities()
        provideDApps()
    }

    func refreshDApps() {
        provideDApps()
    }

    func refreshBlockTime() {
        provideBlockTime()
    }

    func refreshActionDetails() {
        updateActionDetails()
    }

    func refreshIdentities() {
        provideIdentities()
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
    func handleGovMetadata(result: Result<ReferendumMetadataMapping?, Error>, chain _: ChainModel) {
        switch result {
        case let .success(mapping):
            let metadata = mapping?[referendum.index]
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

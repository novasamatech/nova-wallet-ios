import Foundation
import Operation_iOS

final class SwipeGovVotingListInteractor: AnyProviderAutoCleaning {
    weak var presenter: SwipeGovVotingListInteractorOutputProtocol?

    let votingBasketSubscriptionFactory: VotingBasketLocalSubscriptionFactoryProtocol
    let walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol
    let govMetadataLocalSubscriptionFactory: GovMetadataLocalSubscriptionFactoryProtocol
    let govBalanceCalculator: AvailableBalanceMapping

    private let observableState: ReferendumsObservableState

    private let chain: ChainModel
    private let metaAccount: MetaAccountModel

    private let repository: AnyDataProviderRepository<VotingBasketItemLocal>

    private let selectedGovOption: GovernanceSelectedOption

    private var basketItemsProvider: StreamableProvider<VotingBasketItemLocal>?
    private var assetBalanceProvider: StreamableProvider<AssetBalance>?
    private var metadataProvider: StreamableProvider<ReferendumMetadataLocal>?

    private var currentVotingItems: [VotingBasketItemLocal] = []
    private var availableReferendumsStore: UncertainStorage<[ReferendumIdLocal: ReferendumLocal]> = .undefined
    private var balanceStore: UncertainStorage<AssetBalance?> = .undefined
    private var isActive: Bool = false

    private let operationQueue: OperationQueue

    init(
        observableState: ReferendumsObservableState,
        chain: ChainModel,
        metaAccount: MetaAccountModel,
        repository: AnyDataProviderRepository<VotingBasketItemLocal>,
        selectedGovOption: GovernanceSelectedOption,
        votingBasketSubscriptionFactory: VotingBasketLocalSubscriptionFactoryProtocol,
        walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol,
        govMetadataLocalSubscriptionFactory: GovMetadataLocalSubscriptionFactoryProtocol,
        govBalanceCalculator: AvailableBalanceMapping,
        operationQueue: OperationQueue
    ) {
        self.observableState = observableState
        self.chain = chain
        self.metaAccount = metaAccount
        self.repository = repository
        self.selectedGovOption = selectedGovOption
        self.votingBasketSubscriptionFactory = votingBasketSubscriptionFactory
        self.walletLocalSubscriptionFactory = walletLocalSubscriptionFactory
        self.govMetadataLocalSubscriptionFactory = govMetadataLocalSubscriptionFactory
        self.govBalanceCalculator = govBalanceCalculator
        self.operationQueue = operationQueue
    }
}

// MARK: SwipeGovVotingListInteractorInputProtocol

extension SwipeGovVotingListInteractor: SwipeGovVotingListInteractorInputProtocol {
    func setup() {
        subscribeToLocalStorages()

        observableState.addObserver(
            with: self,
            sendStateOnSubscription: true,
            queue: .main
        ) { [weak self] _, new in
            self?.onReceiveObservableState(new.value)
        }
    }

    func removeItem(with identifier: String) {
        deleteItems(with: [identifier])
    }

    func subscribeMetadata() {
        clearAndSubscribeMetadata()
    }

    func subscribeBalance() {
        clearAndSubscribeBalance()
    }

    func subscribeVotingItems() {
        clearAndSubscribeVotingItems()
    }

    func becomeActive() {
        isActive = true

        removeUnavailableIfNeeded()
    }

    func becomeInactive() {
        isActive = false
    }
}

// MARK: VotingBasketLocalStorageSubscriber

extension SwipeGovVotingListInteractor: VotingBasketLocalStorageSubscriber, VotingBasketSubscriptionHandler {
    func handleVotingBasketItems(result: Result<[DataProviderChange<VotingBasketItemLocal>], any Error>) {
        switch result {
        case let .success(votingsChanges):
            currentVotingItems = currentVotingItems.applying(changes: votingsChanges)
            presenter?.didReceive(votingsChanges)

            removeUnavailableIfNeeded()
        case let .failure(error):
            presenter?.didReceive(.votingBasket(error))
        }
    }
}

// MARK: WalletLocalStorageSubscriber

extension SwipeGovVotingListInteractor: WalletLocalStorageSubscriber, WalletLocalSubscriptionHandler {
    func handleAssetBalance(
        result: Result<AssetBalance?, any Error>,
        accountId _: AccountId,
        chainId _: ChainModel.Id,
        assetId _: AssetModel.Id
    ) {
        switch result {
        case let .success(balance):
            balanceStore = .defined(balance)

            presenter?.didReceive(balance)

            removeUnavailableIfNeeded()
        case let .failure(error):
            presenter?.didReceive(.assetBalanceFailed(error))
        }
    }
}

// MARK: GovMetadataLocalStorageSubscriber

extension SwipeGovVotingListInteractor: GovMetadataLocalStorageSubscriber, GovMetadataLocalStorageHandler {
    func handleGovernanceMetadataPreview(
        result: Result<[DataProviderChange<ReferendumMetadataLocal>], any Error>,
        option: GovernanceSelectedOption
    ) {
        guard selectedGovOption == option else {
            return
        }

        switch result {
        case let .success(changes):
            presenter?.didReceive(changes)
        case let .failure(error):
            presenter?.didReceive(.metadataFailed(error))
        }
    }
}

// MARK: Private

private extension SwipeGovVotingListInteractor {
    func deleteItems(with identifiers: [String]) {
        let deleteOperation = repository.saveOperation({
            []
        }, {
            identifiers
        })

        operationQueue.addOperation(deleteOperation)
    }

    func subscribeToLocalStorages() {
        clearAndSubscribeBalance()
        clearAndSubscribeMetadata()
        clearAndSubscribeVotingItems()
    }

    func clearAndSubscribeBalance() {
        guard
            let accountId = metaAccount.fetch(for: chain.accountRequest())?.accountId,
            let assetId = chain.utilityAsset()?.assetId
        else {
            return
        }

        clear(streamableProvider: &assetBalanceProvider)

        assetBalanceProvider = subscribeToAssetBalanceProvider(
            for: accountId,
            chainId: chain.chainId,
            assetId: assetId
        )
    }

    func clearAndSubscribeVotingItems() {
        clear(streamableProvider: &basketItemsProvider)

        basketItemsProvider = subscribeToVotingBasketItemProvider(
            for: chain.chainId,
            metaId: metaAccount.metaId
        )
    }

    func clearAndSubscribeMetadata() {
        clear(streamableProvider: &metadataProvider)

        metadataProvider = subscribeGovernanceMetadata(for: selectedGovOption)
    }

    func onReceiveObservableState(_ state: ReferendumsState) {
        let filteredReferendums = ReferendumFilter.VoteAvailable(
            referendums: state.referendums,
            accountVotes: state.voting?.value?.votes
        ).callAsFunction()

        availableReferendumsStore = .defined(filteredReferendums)

        removeUnavailableIfNeeded()
    }

    func removeUnavailableIfNeeded() {
        guard isActive else {
            return
        }

        let unavailableItems = currentVotingItems.filter { item in
            !checkAvailability(for: item) ||
                !checkAmount(for: item)
        }

        guard !unavailableItems.isEmpty else { return }

        let deleteIds = unavailableItems.map(\.identifier)
        deleteItems(with: deleteIds)
    }

    func checkAvailability(for votingItem: VotingBasketItemLocal) -> Bool {
        guard case let .defined(availableReferendums) = availableReferendumsStore else {
            return true
        }

        return availableReferendums[votingItem.referendumId] != nil
    }

    func checkAmount(for votingItem: VotingBasketItemLocal) -> Bool {
        guard case let .defined(optBalance) = balanceStore else {
            return true
        }

        guard let balance = optBalance else {
            return false
        }

        return votingItem.amount <= govBalanceCalculator.availableBalance(from: balance)
    }
}
